#!/bin/bash

USAGE="Usage: loadimgs <imagedir>"
if [ $# -ne 1 ];then
  echo $USAGE
  exit 1
fi

if [ ! -d $1 ]; then
  echo "$1 is not a dir"
fi

cd $1
iar=(`ls ./*.tar`)
for image in ${iar[@]}
do
  docker load -i $image
done
