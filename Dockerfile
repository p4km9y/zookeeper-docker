FROM java:openjdk-8
MAINTAINER p4km9y

ARG ZK_SERVER_HEAP
ENV ZK_SERVER_HEAP ${ZK_SERVER_HEAP:-512}
ARG ZK_CLIENT_HEAP
ENV ZK_CLIENT_HEAP ${ZK_CLIENT_HEAP:-256}
 
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# >= zookeeper-3.5.1-alpha, might be "current" once
RUN current=http://www.apache.org/dist/zookeeper/zookeeper-3.5.1-alpha && \
    ref=`wget -qO - ${current} | sed -n 's/.*href="\(.*zookeeper-.*\..*gz\)".*/\1/p'` && \
    wget -O - ${current}/${ref} | gzip -dc | tar x -C /opt/ -f - && \
    dir=`ls /opt | grep zookeeper` && \
    ln -s /opt/${dir} /opt/zookeeper && \
    mkdir -p /opt/zookeeper/data && \
    mkdir -p /opt/zookeeper/log

COPY zk-init.sh /opt/zookeeper/bin/

RUN adduser --no-create-home --home /opt/zookeeper --system --disabled-password --disabled-login zookeeper && \
    cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg && \
    sed -i 's/^\(dataDir\)\s*=.*$/\1=\/opt\/zookeeper\/data/' /opt/zookeeper/conf/zoo.cfg && \
    echo "standaloneEnabled=false" >> /opt/zookeeper/conf/zoo.cfg && \
    echo "dynamicConfigFile=/opt/zookeeper/conf/zoo.cfg.dynamic" >> /opt/zookeeper/conf/zoo.cfg && \
    chown -R zookeeper:root /opt/zookeeper/ && \
    chmod +x /opt/zookeeper/bin/*.sh

#    echo "export JVMFLAGS=-Xmx${JAVA_MAX_HEAP}" >> /opt/zookeeper/conf/java.env

USER zookeeper

EXPOSE 2181 2888 3888 9010 8080

ENTRYPOINT ["/opt/zookeeper/bin/zk-init.sh"]

