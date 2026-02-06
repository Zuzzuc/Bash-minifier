#!/bin/bash
cat file.txt | grep "pattern" | wc -l
result=$(echo "hello" | tr 'a-z' 'A-Z')
echo $result
