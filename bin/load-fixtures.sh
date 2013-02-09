#!/bin/sh

for i in ./plugins/*/fixtures/*.json; do
  echo "Loading $i..."
  cat $i | mongoimport -h ${1:-localhost} -d onering -c $(basename $i .json) --upsert --jsonArray
done
