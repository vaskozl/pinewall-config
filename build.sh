#!/bin/sh
docker build --no-cache -t pinewall .
docker create --name pinewall pinewall
docker cp pinewall:/tmp/images/. .
docker rm pinewall
