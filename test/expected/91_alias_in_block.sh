#!/bin/bash
if true; then shopt -s expand_aliases
alias greet='echo hello'
fi
greet world
x=1 ; echo "x=$x" &
wait;