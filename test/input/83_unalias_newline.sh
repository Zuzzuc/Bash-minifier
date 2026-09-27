#!/bin/bash
# unalias changes how later lines are parsed, like alias and shopt.
shopt -s expand_aliases
alias greet='echo ALIAS'
greet
unalias greet
greet() { echo FUNC; }
greet
