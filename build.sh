#!/bin/sh
docker build -t pinewall .
docker create --name pinewall pinewall
docker cp pinewall:/tmp/images/. .
docker rm pinewall
