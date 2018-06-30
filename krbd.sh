#!/bin/sh

DATA_DIR="/home/sasha/KRB/data"
LOG_DIR="/home/sasha/KRB/log"
RUN_DIR="/home/sasha/KRB/run"
TMP_DIR="/home/sasha/KRB/tmp"
HTDOCS_DIR="/home/sasha/KRB/htdocs/blockchain"

KRBD="/home/sasha/KRB/bin/karbowanecd"

KRBD_P2P_IP="0.0.0.0"
KRBD_P2P_PORT="32347"
KRBD_RPC_IP="127.0.0.1"
KRBD_RPC_PORT="32348"
KRBD_LOG_LEVEL="2"
KRBD_FEE_ADDRESS="Ke5tURH8PotZfvk3B444EtEu29PwtjTND4SBmw1NL7gd9gZ6y78F9cz4ZKepay2o2uH4HXu4poTUeJ4FyQMiaTukLKgrpLS"

KRBS_CONTROL="/home/sasha/KRB/init/krbs.sh"

SIGTERM_TIMEOUT=240
SIGKILL_TIMEOUT=120

ZIP="/usr/bin/zip"


## Base check

# Check all sys directories
if [ -d $DATA_DIR ]; then
  if [ ! -w $DATA_DIR ]; then
    echo "Error: DATA dir not writable!"
    exit 1
  fi
else
  echo "Error: DATA dir not found!"
  exit 1
fi

if [ -d $LOG_DIR ]; then
  if [ ! -w $LOG_DIR ]; then
    echo "Error: LOG dir not writable!"
    exit 1
  fi
else
  echo "Error: LOG dir not found!"
  exit 1
fi

if [ -d $RUN_DIR ]; then
  if [ ! -w $RUN_DIR ]; then
    echo "Error: RUN dir not writable!"
    exit 1
  fi
else
  echo "Error: RUN dir not found!"
  exit 1
fi

if [ -d $TMP_DIR ]; then
  if [ ! -w $TMP_DIR ]; then
    echo "Error: TMP dir not writable!"
    exit 1
  fi
else
  echo "Error: TMP dir not found!"
  exit 1
fi

if [ -d $HTDOCS_DIR ]; then
  if [ ! -w $HTDOCS_DIR ]; then
    echo "Error: HTDOCS dir not writable!"
    exit 1
  fi
else
  echo "Error: HTDOCS dir not found!"
  exit 1
fi

# Check all files
if [ ! -f $KRBD ]; then
  echo "Error: DEAMON bin file not found!"
  exit 1
fi

if [ ! -f $ZIP ]; then
  echo "Error: ZIP archiver bin file not found!"
  exit 1
fi

if [ ! -f $KRBS_CONTROL ]; then
  echo "Error: KRBS start script file not found!"
  exit 1
fi



# Function logger
logger(){
  if [ ! -f $LOG_DIR/krbd_control.log ]; then
    touch $LOG_DIR/krbd_control.log
  fi
  mess=[$(date '+%Y-%m-%d %H:%M:%S')]" "$1
  echo $mess >> $LOG_DIR/krbd_control.log
  echo $mess
}

# Funstion locker
locker(){
  if [ "$1" = "check" ]; then
    if [ -f $RUN_DIR/krbd_control.lock ]; then
      logger "Locker: previous task is not completed. Exiting..."
      exit 0
    fi
  fi
  if [ "$1" = "init" ]; then
    touch $RUN_DIR/krbd_control.lock
  fi
    if [ "$1" = "end" ]; then
    rm -f $RUN_DIR/krbd_control.lock
  fi
}

# Function init service
service_init(){
  $KRBD --data-dir $DATA_DIR \
        --log-file $LOG_DIR/krbd.log \
        --log-level $KRBD_LOG_LEVEL \
        --restricted-rpc \
        --no-console \
        --p2p-bind-ip $KRBD_P2P_IP \
        --p2p-bind-port $KRBD_P2P_PORT \
        --rpc-bind-ip $KRBD_RPC_IP \
        --rpc-bind-port $KRBD_RPC_PORT \
        --fee-address $KRBD_FEE_ADDRESS > /dev/null & echo $! > $RUN_DIR/KRBD.pid
}

# Function is ready
service_is_ready(){
  sleep 5
  for i in $(seq 1 30); do
    if [ -f $RUN_DIR/KRBD.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
      cpu_load=$(top -b -n 1 -d 1 -p $pid | grep $pid | sed 's/^\s//g' | sed 's/\s\+/\n/g' | sed -n 9p | sed 's/[^0-9,]*//g' | sed 's/,.*//g')
      logger "-> Node load CPU: "$cpu_load
      if [ "$cpu_load" -lt 5 ]; then
        break
      fi
    fi
    sleep 3
  done
}

# Function start service
service_start(){
  if [ ! -f $RUN_DIR/KRBD.pid ]; then
    logger "Start: try service starting..."
    service_init
    sleep 5
    if [ -f $RUN_DIR/KRBD.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
      if [ -f /proc/$pid/stat ]; then
        logger "Start: service started successfully!"
      fi
    fi
  else
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "Start: service already started"
    else
      logger "Start: service not started, but pid file is found. Tring start again..."
      rm -f $RUN_DIR/KRBD.pid
      service_init
      sleep 5
      if [ -f $RUN_DIR/KRBD.pid ]; then
        pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
        if [ -f /proc/$pid/stat ]; then
          logger "Start: service started successfully!"
        fi
      fi
    fi
  fi
}

# Function stop service
service_stop(){
  if [ -f $RUN_DIR/KRBD.pid ]; then
    logger "Stop: try service stoping..."
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
    if [ -f /proc/$pid/stat ]; then
      kill $pid
      sleep 5
      for i in $(seq 1 $SIGTERM_TIMEOUT); do
        if [ ! -f /proc/$pid/stat ]; then
          rm -f $RUN_DIR/KRBD.pid
          logger "Stop: service was stoped successfully!"
          break
        fi
        sleep 1
      done
      if [ -f $RUN_DIR/KRBD.pid ]; then
        logger "Stop: error stop service! But, try again this..."
        kill -9 $pid
        sleep 5
        for i in $(seq 1 $SIGKILL_TIMEOUT); do
          if [ ! -f /proc/$pid/stat ]; then
            rm -f $RUN_DIR/KRBD.pid
            logger "Stop: sended SIGKILL (kill -9) and remove PID file. Service stoped extremaly!"
            break
          fi
          sleep 1
        done
      fi
    else
      logger "Stop: service not started, but pid file is found. Maybe, something is wrong..."
      rm -f $RUN_DIR/KRBD.pid
    fi
  else
    logger "Stop: service not started!"
  fi
}

# Function archiver blockchain
archiver(){
  if [ -f $DATA_DIR/blocks.dat ] && [ -f $DATA_DIR/blockindexes.dat ]; then
    cd $TMP_DIR
    if [ -d blockchain ]; then
      rm -rf -f blockchain
    fi
    mkdir blockchain
    logger "Archiver: copying target files..."
    cp $DATA_DIR/blocks.dat blockchain/blocks.dat
    cp $DATA_DIR/blockindexes.dat blockchain/blockindexes.dat
    logger "Archiver: archiving target files..."
    $ZIP -r blockchain.zip blockchain
    logger "Archiver: calculating md5sum..."
    md5sum blockchain.zip >> blockchain.txt
    rm -rf -f blockchain
    if [ -f $HTDOCS_DIR/blockchain.zip ]; then
      rm -f $HTDOCS_DIR/blockchain.zip
    fi
    if [ -f $HTDOCS_DIR/blockchain.txt ]; then
      rm -f $HTDOCS_DIR/blockchain.txt
    fi
    mv blockchain.zip $HTDOCS_DIR/blockchain.zip
    mv blockchain.txt $HTDOCS_DIR/blockchain.txt
    logger "Archiver: ok!"
  else
    logger "Archiver: error - no found target files"
  fi
}

# Function checker
checker(){
  logger "Checker: init..."
  if [ -f $RUN_DIR/KRBD.pid ]; then
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "Checker: all fine!"
    else
      logger "Checker: service not started, but pid file found!"
      do_restart
    fi
  else
    logger "Checker: service not was started!"
  fi
}

# Fucntion check simplewallet is was started
IS_KRBS="stop"
is_run_simplewallet(){
  if [ -f $RUN_DIR/KRBD.pid ]; then
    IS_KRBS="run"
  fi
}


do_start(){
  logger "Do start: init procedure..."
  service_start
  logger "Do start: ok"
}

do_stop(){
  is_run_simplewallet
  logger "Do stop: init procedure..."
  if [ "$IS_KRBS" = "run" ]; then
    logger "Do stop: Simplewallet was started and will be stopped. Stopping Simplewallet service..."
    $KRBS_CONTROL --stop > /dev/null
  fi
  service_stop
  logger "Do stop: ok"
}

do_restart(){
  is_run_simplewallet
  logger "Do restart: init procedure..."
  if [ "$IS_KRBS" = "run" ]; then
    logger "Do restart: Simplewallet was started and will be stopped. Stopping Simplewallet service..."
    $KRBS_CONTROL --stop > /dev/null
  fi
  service_stop
  service_start
  if [ "$IS_KRBS" = "run" ]; then
    logger "Do restart: Simplewallet will be started again. Waiting for the node to be ready..."
    service_is_ready
    logger "Do restart: starting Simplewallet service..."
    $KRBS_CONTROL --start > /dev/null
  fi
  logger "Do restart: ok"
}

do_check(){
  logger "Do check: init procedure..."
  checker
  logger "Do check: ok"
}

do_archiver(){
  logger "Do archiver: init procedure..."
  service_stop
  archiver
  service_start
  logger "Do archiver: ok"
}


# Command selector
locker "check"
locker "init"

case "$1" in
  "--start")
  do_start
  ;;
  "--stop")
  do_stop
  ;;
  "--restart")
  do_restart
  ;;
  "--check")
  do_check
  ;;
  "--archive")
  do_archiver
  ;;
  *)
  logger "Selector: command selection error!"
  ;;
esac

locker "end"
