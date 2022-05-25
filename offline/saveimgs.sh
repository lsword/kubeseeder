#!/bin/bash

rm -rf images
mkdir images
while read image
do
iar=(`echo $image | tr '/' ' '`)
echo $image
imagename=${iar[${#iar[@]}-1]}
echo $imagename
docker save -o images/$imagename.tar $image
done < imgs
