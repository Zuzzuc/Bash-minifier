#!/bin/bash
# "builtin alias" defines an alias too.
shopt -s expand_aliases
builtin alias e='echo via builtin'
e hi
