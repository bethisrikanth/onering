#!/bin/bash
PLUGINS="$@"

[ -z "$PLUGINS" ] && PLUGINS="core $(ls -1 plugins | grep -v core | tr \"\\n\" ' ' | sed 's/\.\/public\///g')"
[ -z "$PLUGINS" ] && (echo 'Must specify at least one plugin to generate resources for!' 1>&2 && exit 1)

echo "Generating static assets for plugins: $PLUGINS"


# clear out and remake destination
echo "Cleaning out ./public folder..."
rm -rf ./public
mkdir ./public

# merge all assets into a single tree
echo "Merging plugin subtrees..."
for i in $PLUGINS; do
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
  for j in $PLUGINS; do
    if [ -d ./plugins/$j/public/$i ]; then
      for k in ./plugins/$j/public/$i/*.js; do
        FILE="./public/$i/$(basename $k)"
        cat $k >> $FILE
        echo -e "\n// end file $k\n\n" >> $FILE 
      done
    fi
  done
done

echo "Done."
