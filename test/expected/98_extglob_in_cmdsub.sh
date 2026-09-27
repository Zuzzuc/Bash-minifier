#!/bin/bash
f() { shopt -s extglob; }
x=$(f;true &wait
[[ a == @(a|b) ]] && echo yes);echo "[$x]";