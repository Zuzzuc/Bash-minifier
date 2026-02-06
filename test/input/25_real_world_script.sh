#!/bin/bash
set -e
LOG_DIR="/var/log"
mkdir -p "$LOG_DIR"
for file in "$LOG_DIR"/*.log;do
    if [ -f "$file" ];then
        size=$(wc -c < "$file")
        if [ $size -gt 1000 ];then
            echo "Large: $file"
        fi
    fi
done
echo "Scan complete"
