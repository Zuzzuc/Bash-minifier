#!/bin/bash
declare -a arr=(
  "a b"   # first
  c
)
echo "${#arr[@]}" "${arr[0]}"
