#!/bin/bash
shopt -s expand_aliases
alias greet='echo ALIAS'
greet
unalias greet
greet() { echo FUNC; }
greet;