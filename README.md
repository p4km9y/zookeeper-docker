```bash
#docker build -t p4km9y/zookeeper -t zookeeper .
#docker login
#docker push p4km9y/zookeeper

# cleanup
# docker images | grep none | tr -s [[:space:]] | cut -d\  -f3 | xargs docker rmi -f

# leader
docker run --net=host --name z1 p4km9y/zookeeper 1

# members
ip=`docker inspect z1 | sed -n 's/^\(.*"IPAddress"\s*:\s*"\(.\+\)".*\)$/\2/p' | uniq`
docker run --net=host --name z2 p4km9y/zookeeper ${ip}
```
