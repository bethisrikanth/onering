#!/bin/sh

for i in ./plugins/*/fixtures/*.json; do
  echo "Loading $i..."
  cat $i | mongoimport -d onering -c $(basename $i .json) --upsert --jsonArray
done
