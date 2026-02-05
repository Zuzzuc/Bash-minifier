#!/bin/bash
result=$(echo "line1" \
    && echo "line2" \
    && echo "line3")
echo $result
