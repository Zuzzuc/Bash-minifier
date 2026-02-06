#!/bin/bash
for i in 1 2 3
do
    echo $i
done
if [ -f "test.txt" ]
then
    echo "exists"
else
    echo "nope"
fi
