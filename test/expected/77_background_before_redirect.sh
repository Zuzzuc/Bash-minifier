#!/bin/bash
echo "background" & >out.txt echo "foreground";wait;echo "file: $(cat out.txt)";true & >>out.txt echo "appended";wait;cat out.txt;