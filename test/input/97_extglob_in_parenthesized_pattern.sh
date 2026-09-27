#!/bin/bash
# An extglob pattern inside a parenthesized [[ ]] group (bash 3.2 needs
# extglob on when this is parsed).
f() { shopt -s extglob; }
f
x=a
[[ ( $x == @(a|b) ) ]] && echo yes
