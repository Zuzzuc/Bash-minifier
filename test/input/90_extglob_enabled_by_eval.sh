#!/bin/bash
# extglob is enabled through eval (as with a sourced file, the shopt is not
# visible). A function body is parsed where it is defined.
opts='shopt -s extglob'
eval "$opts"
kind() {
  case $1 in
    +([0-9])) echo "number: $1" ;;
    *) echo "text: $1" ;;
  esac
}
kind 42
kind abc
