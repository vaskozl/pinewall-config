#!/bin/sh

# Define source and destination directories
SRC="pinewall"
FILES=($(find config -type f))

# Loop through the list of files and copy them
for file in "${FILES[@]}"; do
  scp -r "$SRC:${file#config}" "./$file"
done
