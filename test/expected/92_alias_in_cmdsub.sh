#!/bin/bash
shopt -s expand_aliases
setup() { alias e='echo expanded'; }
x=$(setup
e hi)
echo "[$x]"
cat <(setup
e hi)
x=$(echo "<$(setup
e hi)>")
echo "[$x]";