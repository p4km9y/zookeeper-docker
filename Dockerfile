FROM openjdk:8-slim
MAINTAINER p4km9y

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y dnsutils wget iproute2

ARG ZK_SERVER_HEAP
ENV ZK_SERVER_HEAP ${ZK_SERVER_HEAP:-384}
ARG ZK_CLIENT_HEAP
ENV ZK_CLIENT_HEAP ${ZK_CLIENT_HEAP:-256}

ENV ZK_VERSION 3.5.3-beta
ENV ZK_LEADER ""
ENV ZK_SLEEP -1

# beta bug: not a gzip archive: wget -O - ${current}/${ref} | gzip -dc | tar x -C /opt/ -f - && \
RUN cd /opt && \
    current=http://www.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION} && \
    ref=`wget -qO - ${current} | sed -n 's/.*href="\(.*zookeeper-.*\..*gz\)".*/\1/p'` && \
    wget -O - ${current}/${ref} | tar x -C /opt/ -f - && \
    dir=`ls /opt | grep zookeeper` && \
    ln -s ${dir} zookeeper && \
    cd /opt/zookeeper && \
    rm -rf docs src && \
    mkdir -p /opt/zookeeper/volume/data && \
    mkdir -p /opt/zookeeper/volume/logs && \
    mv conf volume/ && \
    ln -s volume/conf conf && \
    ln -s volume/data data && \
    ln -s volume/logs logs

# skipacl=yes not "true" as one would expect
RUN groupadd --system zookeeper && \
    adduser --ingroup zookeeper --system --no-create-home --home /opt/zookeeper --disabled-password --disabled-login zookeeper && \
    cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg && \
    sed -i 's/^\(dataDir\)\s*=.*$/\1=\/opt\/zookeeper\/data/' /opt/zookeeper/conf/zoo.cfg && \
    sed -i 's/^\s*\(rm\s\+.*ZOOPIDFILE.*\)$/while ps -p \$\(cat "$ZOOPIDFILE"\) > \/dev\/null; do sleep 1; echo "waiting for process termination"; done;\1/' /opt/zookeeper/bin/zkServer.sh && \
    echo "standaloneEnabled=false" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "reconfigEnabled=true" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "quorumListenOnAllIPs=true" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "skipACL=yes" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "dynamicConfigFile=/opt/zookeeper/conf/zoo.cfg.dynamic" >> /opt/zookeeper/conf/zoo.cfg

COPY --chown=zookeeper:zookeeper zk-init.sh /opt/zookeeper/bin/
COPY wait-for-it.sh /

RUN chown -R zookeeper:zookeeper /opt/zookeeper/ && \
    chmod +x /opt/zookeeper/bin/*.sh && \
    chmod +x /*.sh

USER zookeeper

VOLUME ["/opt/zookeeper/volume"]

EXPOSE 2181 2888 3888 9010 8080

ENTRYPOINT ["/opt/zookeeper/bin/zk-init.sh"]

