#!/bin/bash
enable_extglob() { shopt -s extglob
};enable_extglob
for f in a.jpg b.txt; do case $f in *.@(jpg|png)) echo "image: $f" ;;*) echo "other: $f" ;;esac;done
[[ b.txt == !(*.jpg) ]] && echo "not a jpg";