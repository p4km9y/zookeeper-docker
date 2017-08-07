#!/bin/bash

#
# http://container-solutions.com/dynamic-zookeeper-cluster-with-docker/
#

ZK=${ZK_LEADER:-$1}

IPADDRESSES=`ip -4 addr show scope global dev eth0 | grep inet | awk '{print \$2}' | cut -d / -f 1`
for ADDR in ${IPADDRESSES}; do
    HOST=`host ${ADDR} | grep -v found | cut -d\  -f 5 | cut -d. -f1`
    if [ -n "${HOST}" ]; then
        break
    fi
done
if [ -z "${HOST}" ]; then
  HOST="${ADDR}"
  echo "reverse dns lookup unsuccessful, using ip address"
fi
echo -e "host: name: ${HOST} ip address: {\n${IPADDRESSES}\n}"

DYN=`ls /opt/zookeeper/conf/zoo.cfg.dynamic* | wc -w`
MYID=1
echo "zookeeper leader address: ${ZK}"
cd /opt/zookeeper

if [ -n "${ZK}" ]; then
  if [ "${ZK_SLEEP}" -lt 0 ]; then
    ZK_SLEEP=`shuf -i3-30 -n1`
  fi
  echo "sleeping for ${ZK_SLEEP} secs to avoid parallel reconfiguration"
  sleep ${ZK_SLEEP}

  echo "awaken: getting leader configuration"
  output=`/opt/zookeeper/bin/zkCli.sh -server ${ZK}:2181 get /zookeeper/config | grep ^server | tr '[:space:]' '\n'`
  echo -e "server response: zookeeper config: {\n${output}\n}"

  if [ -z "${output}" ]; then
    echo "leader communication error: trying existing cfg"
    if [ "${DYN}" -gt 1 ]; then
      echo "existing config found: going to start server"
      output="${HOST}" # just for condition to pass
    else
      echo "existing config not found: exitting"
      exit 10
    fi
  fi

  MYID=`grep ${HOST} <<< "${output}" | cut -d= -f1 | cut -d. -f2`
  if [ -z "${MYID}" ]; then
    for ADDR in ${IPADDRESSES}; do
      MYID=`grep ${ADDR} <<< "${output}" | cut -d= -f1 | cut -d. -f2`
      if [ -n "${MYID}" ]; then
          echo "ip address found in leader configuration: id=${MYID}"
          break
      fi
    done
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
      ZOO_LOG_DIR=/opt/zookeeper/logs ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start
      sleep 5

      echo "starting leader reconfiguration"
      /opt/zookeeper/bin/zkCli.sh -server ${ZK}:2181 reconfig -add "server.${MYID}=${HOST}:2888:3888:participant;2181"
      echo "stopping reconfigured server"
      ZOO_LOG_DIR=/opt/zookeeper/logs /opt/zookeeper/bin/zkServer.sh stop
    fi
  fi

  echo "starting server: ${MYID}"
  ZOO_LOG_DIR=/opt/zookeeper/logs ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start-foreground
else
  if [ "${DYN}" -lt 2 ]; then
    echo "initializing leader"
    # incremental reconfiguration changes dnamic file suffix - so it counts just for the 1. run anyway
    echo "server.${MYID}=${HOST}:2888:3888;2181" > /opt/zookeeper/conf/zoo.cfg.dynamic
    /opt/zookeeper/bin/zkServer-initialize.sh --force --myid=${MYID}
  fi
  echo "starting leading server"
  ZOO_LOG_DIR=/opt/zookeeper/logs ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' /opt/zookeeper/bin/zkServer.sh start-foreground
fi
