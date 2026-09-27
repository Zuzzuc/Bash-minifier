#!/bin/bash
# extglob is enabled by a function call. The minifier cannot see that, but
# it can see the patterns: each command using one starts on a new line.
enable_extglob() {
  shopt -s extglob
}
enable_extglob
for f in a.jpg b.txt; do
  case $f in
    *.@(jpg|png)) echo "image: $f" ;;
    *) echo "other: $f" ;;
  esac
done
[[ b.txt == !(*.jpg) ]] && echo "not a jpg"
