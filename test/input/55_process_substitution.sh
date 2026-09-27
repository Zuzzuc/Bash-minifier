#!/bin/bash
while read -r l; do echo "$l"; done < <(printf 'a\nb\n')
echo ok
