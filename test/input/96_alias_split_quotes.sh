#!/bin/bash
# Quotes in the middle of a word do not hide it either.
command shopt -s "expand_"aliases
a\lias e='echo split quotes'
e hi
