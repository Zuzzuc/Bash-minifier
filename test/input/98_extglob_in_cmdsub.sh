#!/bin/bash
# An extglob pattern inside $( ), after a line ending in "&": the newline in
# front of it is put back (it was dropped, so it is inserted).
f() { shopt -s extglob; }
x=$(
  f
  true &
  wait
  [[ a == @(a|b) ]] && echo yes
)
echo "[$x]"
