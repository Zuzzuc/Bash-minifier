#!/bin/bash
while read -r line;do
    echo "Line: $line"
done < input.txt
echo "Done reading"
