#!/bin/bash
cat file.txt | grep "pattern" | wc -l;cd /tmp && echo "ok";cd /tmp || echo "fail";
