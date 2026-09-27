#!/bin/bash
f() { shopt -s extglob; }
f;x=a
[[ ( $x == @(a|b) ) ]] && echo yes;