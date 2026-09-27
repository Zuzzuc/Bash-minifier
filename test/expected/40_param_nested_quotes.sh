#!/bin/bash
y=${x:-"a # b"};echo "$y";echo "${z:-$(echo "q # r")}";