#!/bin/bash
# An alias defined inside a block is only used by lines parsed after the
# block has run.
if true; then
  shopt -s expand_aliases
  alias greet='echo hello'
fi
greet world
x=1 ; echo "x=$x" &
wait
