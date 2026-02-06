#!/bin/bash
for i in 1 2 3;do
    if [ $i -eq 2 ];then
        echo "found it"
    else
        echo "not yet"
    fi
done
