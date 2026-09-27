#!/bin/bash
f() { echo in f; };time -p
f;time;
f;time -p f;time f;if true; then time
echo x;fi;{ time
echo y; };echo time;