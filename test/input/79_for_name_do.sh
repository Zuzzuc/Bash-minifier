#!/bin/bash
# "for NAME do" (no "in", no ";") loops over the positional parameters.
set -- one two
for arg do
  echo "arg: $arg"
done
f() {
  for a do echo "f: $a"; done
}
f p q
for do in x y; do
  echo "variable named do: $do"
done
for i in a do b; do
  echo "word: $i"
done
select s do
  break
done </dev/null
echo "after select"
