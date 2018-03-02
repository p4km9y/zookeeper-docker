# useful shell snippets

## cleanup
```bash
docker images | grep none | tr -s [[:space:]] | cut -d\  -f3 | xargs docker rmi -f
```

## standalone setup
```bash
# leader
docker run --name z1 p4km9y/zookeeper
# members
ip=`docker inspect z1 | sed -n 's/^\(.*"IPAddress"\s*:\s*"\(.\+\)".*\)$/\2/p' | uniq`
docker run --name z2 -e ZK_LEADER=172.17.0.2 p4km9y/zookeeper
# member run just in leader startup time
docker run --name z2 --entrypoint /wait-for-it.sh zookeeper -t 100 -s 172.17.0.3:2181 -- /opt/zookeeper/bin/zk-init.sh 172.17.0.3
```

## compose setup
```bash
docker-compose up
```
