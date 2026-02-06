#!/bin/bash
case $1 in
    -h|--help)
        echo "Usage: script.sh [options]"
        ;;
    -v|--version)
        echo "1.0.0"
        ;;
    *)
        echo "Unknown option"
        ;;
esac
