#!/bin/bash
shopt -s extglob
x=b
case $x in @(a|b)) echo m ;; esac
shopt -s expand_aliases
alias hi='echo hi'
hi
