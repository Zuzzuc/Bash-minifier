#!/bin/bash
x=$((echo a) | cat)
echo "$x"
y=$((echo b); echo c)
echo "$y"
((echo d) | cat)
echo $(( (1+2) * 3 ))
(( (1+2) > 2 )) && echo arith
z=$((echo e)
)
echo "$z"
(
  (echo f)
)
w=$(
  (echo g)
)
echo "$w"
echo $((1<<2)) $((16#ff))
