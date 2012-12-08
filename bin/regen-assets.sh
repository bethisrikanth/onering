#!/bin/bash

[ $# -eq 0 ] && (echo 'Must specify at least one plugin to generate resources for!' 1>&2 && exit 1)

# clear out and remake destination
rm -rf ./public
mkdir ./public

# merge all assets into a single tree
for i in $@; do
  if [ -d ./plugins/$i/public ]; then
    for j in ./plugins/$i/public/*; do
      cp -Rp $j ./public/
    done
  fi
done

for i in js; do
# create destination directories
  mkdir -p ./public/$i

# empty out top-level files of type i
  for j in ./public/$i/*.$i; do
    > $j
  done

# aggregate like-named files of type i
  for j in $@; do
    if [ -d ./plugins/$j/public/$i ]; then
      for k in ./plugins/$j/public/$i/*.js; do
        FILE="./public/$i/$(basename $k)"
        cat $k >> $FILE
        echo -e "\n// end file $k\n\n" >> $FILE 
      done
    fi
  done
done
