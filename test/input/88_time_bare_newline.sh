#!/bin/bash
# bare "time" / "time -p" (with or without ";") keep a real newline;
# a timed command after them on the same line is joined normally.
f() { echo in f; }
time -p
f
time;
f
time -p f
time f
if true; then
  time
  echo x
fi
{ time
echo y; }
echo time
