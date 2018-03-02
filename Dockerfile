FROM openjdk:8-alpine
MAINTAINER p4km9y

RUN apk add --update wget bind-tools tini bash && \
    rm -rf /var/cache/apk/*

ARG ZK_SERVER_HEAP
ENV ZK_SERVER_HEAP ${ZK_SERVER_HEAP:-384}
ARG ZK_CLIENT_HEAP
ENV ZK_CLIENT_HEAP ${ZK_CLIENT_HEAP:-256}

ENV ZK_VERSION 3.5.3-beta
ENV ZK_LEADER ""
ENV ZK_SLEEP -1

# beta bug: not a gzip archive: wget -O - ${current}/${ref} | gzip -dc | tar x -C /opt/ -f - && \
RUN mkdir /opt && \
    current=http://www.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION} && \
    ref=`wget -qO - ${current} | sed -n 's/.*href="\(.*zookeeper-.*\..*gz\)".*/\1/p'` && \
    wget -O - ${current}/${ref} | tar x -C /opt/ -f - && \
    dir=`ls /opt | grep zookeeper` && \
    ln -s /opt/${dir} /opt/zookeeper && \
    mkdir -p /opt/zookeeper/data && \
    mkdir -p /opt/zookeeper/logs

# skipacl=yes not "true" as one would expect
RUN addgroup -S zookeeper && \
    adduser -S -H -h /opt/zookeeper -g zookeeper zookeeper && \
    cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg && \
    sed -i 's/^\(dataDir\)\s*=.*$/\1=\/opt\/zookeeper\/data/' /opt/zookeeper/conf/zoo.cfg && \
    sed -i 's/^\s*\(rm\s\+.*ZOOPIDFILE.*\)$/while ps -p \$\(cat "$ZOOPIDFILE"\) > \/dev\/null; do sleep 1; echo "waiting for process termination"; done;\1/' /opt/zookeeper/bin/zkServer.sh && \
    echo "standaloneEnabled=false" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "reconfigEnabled=true" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "quorumListenOnAllIPs=true" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "skipACL=yes" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "dynamicConfigFile=/opt/zookeeper/conf/zoo.cfg.dynamic" >> /opt/zookeeper/conf/zoo.cfg && \
    chown -R zookeeper:zookeeper /opt/zookeeper/ && \
    chmod +x /opt/zookeeper/bin/*.sh

USER zookeeper

VOLUME ["/opt/zookeeper/data", "/opt/zookeeper/conf"]

EXPOSE 2181 2888 3888 9010 8080

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/opt/zookeeper/bin/zk-init.sh"]

COPY --chown=zookeeper:zookeeper zk-init.sh /opt/zookeeper/bin/
COPY wait-for-it.sh /
