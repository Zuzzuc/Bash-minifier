#!/bin/bash
# Inside $( ) and <( ) bash parses one command at a time when it runs them,
# so an alias defined by the first command is used by the next one.
shopt -s expand_aliases
setup() { alias e='echo expanded'; }
x=$(
  setup
  e hi
)
echo "[$x]"
cat <(
  setup
  e hi
)
x=$(echo "<$(
  setup
  e hi
)>")
echo "[$x]"
