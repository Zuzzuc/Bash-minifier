#!/bin/bash
# In an unquoted heredoc, \+newline joins lines before the delimiter check.
cat <<EOF
foo\
EOF
bar
EOF
cat <<EOF
E\
OF
cat <<EOF
even\\
EOF
cat <<'EOF'
quoted\
EOF
echo after
