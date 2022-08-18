#!/bin/bash

# use this script in the root directory to add the license header to all files

for i in $(git ls-files | grep "\.swift$"); do
  creationDate=$(git log --follow --diff-filter=A --date=format:'%d.%m.%y %H:%M:%S' $i | grep Date | tail -1 | awk '{ print $2 }')
  creationYear=$(git log --follow --diff-filter=A --date=format:'%Y' $i | grep Date | tail -1 | awk '{ print $2 }')
  filename=$(echo $i | sed "s/.*\///")
  modulename=$(echo $i | awk -F/ '{ print $1 }')
  echo "Info: <$creationYear> <$creationDate> <$modulename> <$filename> from $i"
  cat ./Helper/license-header.txt |sed "s|THEDATE|$creationDate|" |sed "s|THEYEAR|$creationYear|" |sed "s|THEFILENAME|$filename|" |sed "s|THEMODULENAME|$modulename|"| cat - $i > /tmp/temp && mv /tmp/temp $i
done