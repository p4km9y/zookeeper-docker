#!/bin/bash

#
# http://container-solutions.com/dynamic-zookeeper-cluster-with-docker/
#

ZK=${ZK_LEADER:-$1}
IPADDRESS=`ip -4 addr show scope global dev eth0 | grep inet | awk '{print \$2}' | cut -d / -f 1`

HOST=`host ${IPADDRESS} | grep -v found | cut -d\  -f 5 | cut -d. -f1`
if [ -z "${HOST}" ]; then
  HOST="${IPADDRESS}"
  echo "reverse dns lookup unsuccessful, using ip address"
fi
echo "zookeeper host: ${HOST} ip address: ${IPADDRESS}"

MYID=1
echo "zookeeper leader address: ${ZK}"
cd /opt/zookeeper
if [ -n "${ZK}" ]; then
  echo "sleeping for ${ZK_SLEEP} secs to avoid parallel reconfiguration"
  /bin/sleep ${ZK_SLEEP}

  output=`/opt/zookeeper/bin/zkCli.sh -server ${ZK}:2181 get /zookeeper/config | grep ^server | tr '[:space:]' '\n'`
  echo -e "server response: zookeeper config: {\n${output}\n}"

  if [ -z "${output}" ]; then
    echo "leader communication error: exitting"
    exit 10
  fi

  MYID=`grep ${IPADDRESS} <<< "${output}" | cut -d= -f1 | cut -d. -f2`
  if [ -z "${MYID}" ]; then
    MYID=`grep ${HOST} <<< "${output}" | cut -d= -f1 | cut -d. -f2`
    if [ -z "${MYID}" ]; then
      # extract all the zk-ids from the output
      declare -a id_list=()
      while read x; do
        id_list+=(`echo $x | cut -d"=" -f1 | cut -d"." -f2`);
      done <<< "${output}"

      sorted_id_list=( $(
        for el in "${id_list[@]}"; do
          echo "$el";
        done | sort -n) )

      echo "sorted node id list: ${sorted_id_list[@]}"

      # get the next increasing number from the sequence
      MYID=$((${sorted_id_list[${#sorted_id_list[@]}-1]}+1))
      echo "myid: ${MYID}"

      echo "${output}" > /opt/zookeeper/conf/zoo.cfg.dynamic
      echo "server.${MYID}=${HOST}:2888:3888:observer;2181" >> /opt/zookeeper/conf/zoo.cfg.dynamic
      echo "initializing server"
      cp /opt/zookeeper/conf/zoo.cfg.dynamic /opt/zookeeper/conf/zoo.cfg.dynamic.orig
      /opt/zookeeper/bin/zkServer-initialize.sh --force --myid=${MYID}

      echo "starting server for reconfiguration"
      ZOO_LOG_DIR=/opt/zookeeper/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start
      echo "starting leader reconfiguration"
      /opt/zookeeper/bin/zkCli.sh -server ${ZK}:2181 reconfig -add "server.${MYID}=${HOST}:2888:3888:participant;2181"
      echo "stopping reconfigured server"
      /opt/zookeeper/bin/zkServer.sh stop

    fi
  fi

  echo "starting server: ${MYID}"
  ZOO_LOG_DIR=/opt/zookeeper/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start-foreground
  sleep 1000
else
  # seq numbers are appended to dynamic files anyway - its just for the 1. time
  echo "server.${MYID}=${HOST}:2888:3888;2181" > /opt/zookeeper/conf/zoo.cfg.dynamic
  /opt/zookeeper/bin/zkServer-initialize.sh --force --myid=$MYID
  echo "starting leading server"
  ZOO_LOG_DIR=/opt/zookeeper/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start-foreground
fi
