#!/bin/bash

docker rm $(docker ps -q -f status=exited)
docker rmi $(docker images | grep none | awk '{print $3}')

exit 0
