#!/bin/bash
# "time" alone on a line times nothing; it must not time the next command.
f() { echo in f; }
time
f
time -p true
