# Test Files

This directory contains test input files and their expected outputs for the Bash-minifier.

## Structure

```
test/
├── test.sh         # Run tests
├── input/          # Input bash scripts to be minified
│   ├── 01_multiline_backslash.sh
│   ├── ...
│   └── 34_case_inline_terminator.sh
└── expected/       # Expected minified output for each input file
    ├── 01_multiline_backslash.sh
    ├── ...
    └── 34_case_inline_terminator.sh
```

## Test Cases

### 01 - Multiline with Backslash Continuation

Tests that backslash line continuations are properly joined into single lines.

### 02 - No Multiple Semicolons

Ensures the minifier doesn't add double semicolons between statements.

### 03 - If-Then-Else

Tests conditional statements with correct spacing after keywords.

### 04 - For Loop

Validates for loop minification with correct spacing after `do`.

### 05 - Function

Tests function definitions with proper brace and semicolon handling.

### 06 - Comments

Verifies that full-line comments are removed.

### 07 - Empty Lines

Ensures empty lines don't produce extra semicolons.

### 08 - Complex Continuation

Tests multi-line command chains with backslash continuations.

### 09 - Case Statement

Validates case/esac handling with `;;` terminators.

### 10 - While Loop

Tests while loop minification with proper spacing.

### 11 - Keyword Suffix Regression

Ensures words ending in keywords aren't misidentified as bash keywords.

### 12 - Variable Expansion

Tests various parameter expansion forms.

### 13 - Escape Sequences

Verifies escape sequences inside strings are preserved.

### 14 - Standalone Keywords

Tests `do`/`then`/`else` on their own lines.

### 15 - Semicolons in Strings

Ensures semicolons inside quoted strings aren't treated as separators.

### 16 - Nested Structures

Tests nested control flow.

### 17 - Pipes and Subshells

Validates pipes and command substitution.

### 18 - Multiple Functions

Tests multiple function definitions followed by calls.

### 19 - Indented Comments

Verifies removal of comments indented with tabs or spaces.

### 20 - Case Wildcards

Tests case patterns with alternatives and a wildcard default.

### 21 - Arithmetic and Arrays

Tests arithmetic expressions and array syntax.

### 22 - While Read

Tests `while read` with input redirection.

### 23 - Long Continuation

Tests a command split across many continued lines.

### 24 - Hash in Strings

Ensures `#` inside quoted strings isn't stripped as a comment.

### 25 - Real-World Script

End-to-end test with nested loops, conditionals, and substitution.

### 26 - Implicit Continuation

Tests lines ending with `|`, `&&`, or `||` joining with the next line.

### 27 - Inline Comments

Verifies trailing comments are stripped while preserving code.

### 28 - Heredoc

Tests an unquoted heredoc passed through verbatim.

### 29 - Heredoc Quoted

Tests a quoted heredoc delimiter preserving literal content.

### 30 - Multiline String (Double Quote)

Tests a double-quoted string spanning multiple lines.

### 31 - Hash in Parameter Expansion

Tests parameter expansion with `#` not broken by comment stripping.

### 32 - Multiline String (Single Quote)

Tests a single-quoted string spanning multiple lines.

### 33 - Hash Not a Comment

Ensures unquoted `#` after `=` isn't treated as a comment.

### 34 - Case Inline Terminator

Tests case branches written on a single line.

## Adding New Tests

To add a new test:

1. Create an input file in `test/input/` with a descriptive name (e.g., `11_new_feature.sh`)
2. Create the corresponding expected output in `test/expected/` with the same name
3. The test framework will automatically pick it up

## Notes

- Each input file should start with a shebang line (`#!/bin/bash` or similar)
- Expected output files show what the minifier _should_ produce (ideal behavior)
- Some expected outputs may not match current behavior - these represent targets for improvement
