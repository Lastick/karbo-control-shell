#!/bin/sh

DATA_DIR="/home/sasha/KRB/data"
LOG_DIR="/home/sasha/KRB/log"
RUN_DIR="/home/sasha/KRB/run"
TMP_DIR="/home/sasha/KRB/tmp"
HTDOCS_DIR="/var/www/html/blockchain"

KRBD="/home/sasha/KRB/bin/karbowanecd"

KRBD_P2P_IP="0.0.0.0"
KRBD_P2P_PORT="32347"
KRBD_RPC_IP="127.0.0.1"
KRBD_RPC_PORT="32348"
KRBD_LOG_LEVEL="2"
KRBD_FEE_ADDRESS="Ke5tURH8PotZfvk3B444EtEu29PwtjTND4SBmw1NL7gd9gZ6y78F9cz4ZKepay2o2uH4HXu4poTUeJ4FyQMiaTukLKgrpLS"

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

# Check all bin files
if [ ! -f $KRBD ]; then
  echo "Error: DEAMON bin file not found!"
  exit 1
fi

if [ ! -f $ZIP ]; then
  echo "Error: ZIP archiver bin file not found!"
  exit 1
fi

# Function init service
service_init(){
  $KRBD --data-dir $DATA_DIR \
        --log-file $LOG_DIR/krbd.log \
        --log-level $KRBD_LOG_LEVEL \
        --restricted-rpc \
        --no-console \
        --rpc-bind-ip $KRBD_P2P_IP \
        --rpc-bind-port $KRBD_P2P_PORT \
        --p2p-bind-ip $KRBD_RPC_IP \
        --p2p-bind-port $KRBD_RPC_PORT \
        --fee-address $KRBD_FEE_ADDRESS > /dev/null & echo $! > $RUN_DIR/KRBD.pid
}

# Function start service
service_start(){
  if [ ! -f $RUN_DIR/KRBD.pid ]; then
    echo "Start: try service starting..."
    service_init
    sleep 5
    if [ -f $RUN_DIR/KRBD.pid ]; then
      pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
      if [ -f /proc/$pid/stat ]; then
        echo "Start: service started successfully!"
      fi
    fi
  else
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
    if [ -f /proc/$pid/stat ]; then
      echo "Start: service already started"
    else
      echo "Start: service not started, but pid file is found. Tring start again..."
      rm $RUN_DIR/KRBD.pid
      service_init
      sleep 5
      if [ -f $RUN_DIR/KRBD.pid ]; then
        pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
        if [ -f /proc/$pid/stat ]; then
          echo "Start: service started successfully!"
        fi
      fi
    fi
  fi
}

# Function stop service
service_stop(){
  if [ -f $RUN_DIR/KRBD.pid ]; then
    echo "Stop: try service stoping..."
    pid=$(sed 's/[^0-9]*//g' $RUN_DIR/KRBD.pid)
    if [ -f /proc/$pid/stat ]; then
      kill $pid
      sleep 5
      for i in $(seq 1 $SIGTERM_TIMEOUT); do
        if [ ! -f /proc/$pid/stat ]; then
          rm $RUN_DIR/KRBD.pid
          echo "Stop: service was stoped successfully!"
          break
        fi
        sleep 1
      done
      if [ -f $RUN_DIR/KRBD.pid ]; then
        echo "Stop: error stop service! But, try again this..."
        kill -9 $pid
        sleep 5
        for i in $(seq 1 $SIGKILL_TIMEOUT); do
          if [ ! -f /proc/$pid/stat ]; then
            rm $RUN_DIR/KRBD.pid
            echo "Stop: sended SIGKILL (kill -9) and remove PID file. Service stoped extremaly!"
            break
          fi
          sleep 1
        done
      fi
    else
      echo "Stop: service not started, but pid file is found. Maybe, something is wrong..."
      rm $RUN_DIR/KRBD.pid
    fi
  else
    echo "Stop: service not started!"
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
    echo "Archiver: copying target files..."
    cp $DATA_DIR/blocks.dat blockchain/blocks.dat
    cp $DATA_DIR/blockindexes.dat blockchain/blockindexes.dat
    echo "Archiver: archiving target files..."
    $ZIP -r blockchain.zip blockchain
    echo "Archiver: calculating md5sum..."
    md5sum blockchain.zip >> blockchain.txt
    rm -rf -f blockchain
    if [ -f $HTDOCS_DIR/blockchain.zip ]; then
      rm $HTDOCS_DIR/blockchain.zip
    fi
    if [ -f $HTDOCS_DIR/blockchain.txt ]; then
      rm $HTDOCS_DIR/blockchain.txt
    fi
    mv blockchain.zip $HTDOCS_DIR/blockchain.zip
    mv blockchain.txt $HTDOCS_DIR/blockchain.txt
    echo "Archiver: ok!"
  else
    echo "Archiver: error - no found target files"
  fi
}

do_archiver(){
  echo "Do archiver: init procedure..."
  service_stop
  archiver
  service_start
  echo "Do archiver: ok"
}

if [ "$1" = "--start" ]; then
  service_start
fi

if [ "$1" = "--stop" ]; then
  service_stop
fi

if [ "$1" = "--archive" ]; then
  do_archiver
fi

