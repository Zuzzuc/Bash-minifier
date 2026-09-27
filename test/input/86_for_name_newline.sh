#!/bin/bash
# "for NAME" can be followed by a newline before "in" or "do".
for i
in a b
do
  echo "$i"
done
set -- x y
for i
do
  echo "$i"
done
