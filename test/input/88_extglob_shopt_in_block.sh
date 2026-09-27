#!/bin/bash
# extglob is enabled inside a block. The case below uses @( ), which bash only
# accepts if extglob was on when the case was parsed, so the minified script
# must not put it in the same top-level command as the block.
if true; then
  shopt -s extglob
fi
x=foo.tar.gz
case $x in
  *.@(gz|bz2)) echo compressed ;;
  *) echo plain ;;
esac
