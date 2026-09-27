#!/bin/bash
# An alias defined through eval.
shopt -s expand_aliases
eval "alias e='echo via eval'"
e hi
