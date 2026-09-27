#!/bin/bash
coproc { echo a > out_a; };wait;coproc NAMED { echo b > out_b; };wait;coproc echo c > out_c;wait;coproc NAMED2 (echo d > out_d);wait;cat out_a out_b out_c out_d;