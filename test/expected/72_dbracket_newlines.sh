#!/bin/bash
[[ -n a && -n b ]] && echo one;[[ -n a ]] && echo two;[[ ( -n a ) && -n b ]] && echo three;x=b; [[ $x =~ ^(a|b)$ ]] && echo four;