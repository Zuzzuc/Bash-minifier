#!/bin/bash
cat <<END-DOC
x
END-DOC
cat <<E"O"F
y
EOF
cat <<\Z
$z
Z
echo ok;