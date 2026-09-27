#!/bin/bash
# A ";" ending a line must stay separate from a ";;", ";&" or ";;&" on the
# next line: ";" + ";&" glued together would be ";;&", a different terminator.
f() {
  case $1 in
    a) echo "a falls through";
    ;&
    b) echo "b, then test the next patterns";
    ;;&
    *) echo "star" ;   # comment before the terminator
    ;;
  esac
}
f a
f b
f c
case x in
  x) find /dev/null -prune -exec echo "escaped semicolon" \;
  ;;
esac
