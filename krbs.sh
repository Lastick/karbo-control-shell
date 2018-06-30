#!/bin/sh

DATA_DIR="/home/sasha/KRB/data"
LOG_DIR="/home/sasha/KRB/log"
RUN_DIR="/home/sasha/KRB/run"

KRBS="/home/sasha/KRB/bin/simplewallet"

KRBS_NODE_HOST="127.0.0.1"
KRBS_NODE_PORT="32348"
KRBS_WALLET="DevelopWallet.dat"
KRBS_PASS="pass"
KRBS_LOG_LEVEL="3"
KRBS_RPC_IP="127.0.0.1"
KRBS_RPC_PORT="15000"

SIGTERM_TIMEOUT=30
SIGKILL_TIMEOUT=20

KRBS_WALLET=$DATA_DIR/$KRBS_WALLET


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

# Check all bin files
if [ ! -f $KRBS ]; then
  echo "Error: SIMPLEWALLET bin file not found!"
  exit 1
fi

if [ ! -f $KRBS_WALLET.wallet ]; then
  echo "Error: wallet bin file not found!"
  exit 1
fi


# Function logger
logger(){
  if [ ! -f $LOG_DIR/krbs_control.log ]; then
    touch $LOG_DIR/krbs_control.log
  fi
  mess=[$(date '+%Y-%m-%d %H:%M:%S')]" "$1
  echo $mess >> $LOG_DIR/krbs_control.log
  echo $mess
}

# Funstion locker
locker(){
  if [ "$1" = "check" ]; then
    if [ -f $RUN_DIR/krbs_control.lock ]; then
      logger "Locker: previous task is not completed. Exiting..."
      exit 0
    fi
  fi
  if [ "$1" = "init" ]; then
    touch $RUN_DIR/krbs_control.lock
  fi
    if [ "$1" = "end" ]; then
    rm -f $RUN_DIR/krbs_control.lock
  fi
}

# Function init service
service_init(){
  $KRBS --wallet-file $KRBS_WALLET \
        --password $KRBS_PASS \
        --daemon-host $KRBS_NODE_HOST \
        --daemon-port $KRBS_NODE_PORT \
        --log-file $LOG_DIR/krbs.log \
        --log-level $KRBS_LOG_LEVEL > /dev/null & echo $! > $RUN_DIR/KRBS.pid
}

# Function start service
service_start(){
  if [ ! -f $RUN_DIR/KRBS.pid ]; then
    logger "Start: try service starting..."
    service_init
    sleep 5
    if [ -f $RUN_DIR/KRBS.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBS.pid)
      if [ -f /proc/$pid/stat ]; then
        logger "Start: service started successfully!"
      fi
    fi
  else
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBS.pid)
    if [ -f /proc/$pid/stat ]; then
      logger "Start: service already started"
    else
      logger "Start: service not started, but pid file is found. Tring start again..."
      rm -f $RUN_DIR/KRBS.pid
      service_init
      sleep 5
      if [ -f $RUN_DIR/KRBS.pid ]; then
        pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBS.pid)
        if [ -f /proc/$pid/stat ]; then
          logger "Start: service started successfully!"
        fi
      fi
    fi
  fi
}

# Function stop service
service_stop(){
  if [ -f $RUN_DIR/KRBS.pid ]; then
    logger "Stop: try service stoping..."
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBS.pid)
    if [ -f /proc/$pid/stat ]; then
      kill $pid
      sleep 5
      for i in $(seq 1 $SIGTERM_TIMEOUT); do
        if [ ! -f /proc/$pid/stat ]; then
          rm -f $RUN_DIR/KRBS.pid
          logger "Stop: service was stoped successfully!"
          break
        fi
        sleep 1
      done
      if [ -f $RUN_DIR/KRBS.pid ]; then
        logger "Stop: error stop service! But, try again this..."
        kill -9 $pid
        sleep 5
        for i in $(seq 1 $SIGKILL_TIMEOUT); do
          if [ ! -f /proc/$pid/stat ]; then
            rm -f $RUN_DIR/KRBS.pid
            logger "Stop: sended SIGKILL (kill -9) and remove PID file. Service stoped extremaly!"
            break
          fi
          sleep 1
        done
      fi
    else
      logger "Stop: service not started, but pid file is found. Maybe, something is wrong..."
      rm -f $RUN_DIR/KRBS.pid
    fi
  else
    logger "Stop: service not started!"
  fi
}

do_restart(){
  logger "Do restart: init procedure..."
  service_stop
  service_start
  logger "Do restart: ok"
}


# Command selector
locker "check"
locker "init"

case "$1" in
  "--start")
  service_start
  ;;
  "--stop")
  service_stop
  ;;
  "--restart")
  do_restart
  ;;
  *)
  logger "Selector: command selection error!"
  ;;
esac

locker "end"