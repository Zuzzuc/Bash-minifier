# Test Files

This directory contains test input files and their expected outputs for the Bash-minifier.

## Structure

```
test/
├── input/          # Input bash scripts to be minified
│   ├── 01_multiline_backslash.sh
│   ├── 02_no_multiple_semicolons.sh
│   ├── 03_if_then_else.sh
│   ├── 04_for_loop.sh
│   ├── 05_function.sh
│   ├── 06_comments.sh
│   ├── 07_empty_lines.sh
│   ├── 08_continuation_complex.sh
│   ├── 09_case_statement.sh
│   └── 10_while_loop.sh
└── expected/       # Expected minified output for each input file
    ├── 01_multiline_backslash.sh
    ├── 02_no_multiple_semicolons.sh
    ├── 03_if_then_else.sh
    ├── 04_for_loop.sh
    ├── 05_function.sh
    ├── 06_comments.sh
    ├── 07_empty_lines.sh
    ├── 08_continuation_complex.sh
    ├── 09_case_statement.sh
    └── 10_while_loop.sh
```

## Test Cases

### 01 - Multiline with Backslash Continuation

Tests that backslash line continuations are properly converted to single-line format with spaces replacing the backslashes.

### 02 - No Multiple Semicolons

Ensures that the minifier doesn't add double semicolons between statements.

### 03 - If-Then-Else

Tests proper handling of conditional statements with correct spacing after keywords.

### 04 - For Loop

Validates that for loops are properly minified with correct spacing after `do`.

### 05 - Function

Tests function definitions with proper brace and semicolon handling.

### 06 - Comments

Verifies that full-line comments are removed while preserving actual commands.

### 07 - Empty Lines

Ensures empty lines don't result in extra semicolons in the output.

### 08 - Complex Continuation

Tests multi-line command chains with backslash continuations.

### 09 - Case Statement

Validates case/esac statement handling (note: case statements use `;;` which is valid syntax).

### 10 - While Loop

Tests while loop minification with proper spacing.

## Adding New Tests

To add a new test:

1. Create an input file in `test/input/` with a descriptive name (e.g., `11_new_feature.sh`)
2. Create the corresponding expected output in `test/expected/` with the same name
3. The test framework will automatically pick it up

## Notes

- Each input file should start with a shebang line (`#!/bin/bash` or similar)
- Expected output files show what the minifier _should_ produce (ideal behavior)
- Some expected outputs may not match current behavior - these represent targets for improvement
