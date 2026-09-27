#!/bin/bash
# "a &" + newline + ">f b" must not become "a &>f b".
echo "background" &
>out.txt echo "foreground"
wait
echo "file: $(cat out.txt)"
true &
>>out.txt echo "appended"
wait
cat out.txt
