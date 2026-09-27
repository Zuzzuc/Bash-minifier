#!/bin/bash
{ echo a; echo b; } > /dev/null
{ echo c
} >&2
echo d
