#!/bin/bash
# Quotes and backslashes do not hide shopt/alias from the minifier.
shopt -s 'expand_aliases'
\alias e='echo expanded'
e hi
