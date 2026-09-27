#!/bin/bash
if true; then shopt -s extglob
fi;x=foo.tar.gz
case $x in *.@(gz|bz2)) echo compressed ;;*) echo plain ;;esac;