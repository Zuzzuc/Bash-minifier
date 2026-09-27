#!/bin/bash
# $'...' with \' inside "$((" that is really "$( (": the lookahead must skip it.
x=$((echo $'it\'s') | cat)
echo "$x"
