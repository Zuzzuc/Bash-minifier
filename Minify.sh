#!/usr/bin/env bash
# License: The MIT License (MIT)
# Author Zuzzuc https://github.com/Zuzzuc/

# This script will Minify bash scripts.



# Assign variables
# Default vars
force=0
permission="u+x"
mode=RAM
output=stdout
debug=0
self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

#Functions
exitw(){
	# Exit and print exit code.
	# Usage is $1, where $1 is the error code.
	echo "Error code: $1. Exiting"
	exit $1
}

SanitizeFilePath(){
	# This function will remove \ and space at the end of a filepath to make it parse well into other, quoted, functions/commands
	# Usage $1, where $1 is a file path.
	echo -n "$(echo "$(echo "$1" | sed 's%\\%%g')" |sed -e 's%[[:space:]]*$%%')"
}

readLine(){
	# This function will read line $1. Output to stdout
	# Usage is $1, where $1 is the line to read.
	sed "$1q;d" "$file"
}

processData(){
	# This function will format any input line to be able to fit in a one liner.
	# Usage is $1, where $1 is the data.

	# Remove trailing spaces.
	data="$(printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

	ic=0

	# Remove comments
	# Temporary fix, will only remove full line comments...

	# The following line will check if the line contains '#'
	if [[ "$(echo "$data" | grep -q '#';echo $?)" == "0" ]];then

		# Remove any empty characters so comparison will be easier.
		tmpString="$(echo "$data" | sed 's%\t%%g' | sed 's% %%g' | sed 's%\v%%g' | sed 's%\r%%g' | sed 's%\r%%g' | sed 's%\n%%g' )"
		if [ "${tmpString:0:1}" == "#" ];then
			# $data is a full line comment. We'll remove it fully.
			data=""
			ic=1
		fi
	fi

	# We should not run this if data is a full line comment, as it will corrupt the script.
	# Also skip empty lines to avoid adding unnecessary semicolons
	if [ $ic -eq 0 ] && [ -n "$data" ];then
		# Check if line ends with backslash (line continuation)
		if [ "${data: -1}" == "\\" ];then
			# Line continuation - remove backslash and add space (since we're on one line now)
			data="$(echo "$data" | sed 's%[[:space:]]*\\$% %')"
			# Check for implicit line continuation
		elif [ "${data: -1}" == "|" ] || [ "${data: -2}" == "&&" ] || [ "${data: -2}" == "||" ];then
			data="$(echo "$data" | sed "s%$% %")"
		# Look for exceptions
		elif [ "${data: -3}" == ";do" ] || [[ "$data" =~ (^|[[:space:]])do$ ]] || \
		     [ "${data: -5}" == ";then" ] || [[ "$data" =~ (^|[[:space:]])then$ ]] || \
		     [[ "$data" =~ (^|[[:space:]])else$ ]] || \
		     [[ "$data" =~ (^|[[:space:]])elif$ ]] || \
		     [[ "$data" =~ (^|[[:space:]])\{$ ]] || \
		     [[ "$data" =~ (^|[[:space:]])in$ ]];then
			# Add a space
			data="$(echo "$data" | sed "s%$% %")"
		elif [ "${data: -1}" == ")" ] && \
		     [ "$(echo "$data" | tr -cd '(' | wc -c)" -lt "$(echo "$data" | tr -cd ')' | wc -c)" ] && \
		     ! [[ "$data" =~ \&\&|\|\||\; ]];then
			# Case pattern (unbalanced closing paren, no command operators) - add a space
			data="$(echo "$data" | sed "s%$% %")"
		elif [ "${data: -2}" == ";;" ];then
			# Case statement terminator - don't add semicolon
			:
		elif [[ "$data" =~ (^|[[:space:];])\}$ ]];then
			data="$(echo "$data" | sed 's%}$% };%')"
		else
			# Add ';' to end of line.
			data="$(echo "$data" | sed "s%$%;%")"
		fi
	fi

	# Return $data
	printf '%s' "$data"
}

# Handle input
for i in "$@";do
	case $i in
		$self)
		shift
		;;
		-f=*|--file=*)
		file="$(SanitizeFilePath "${i#*=}")"
		if [ "$file" == "$self" ];then
			echo "You are trying to execute this script on itself."
			exitw 5
		fi
		shift
		;;
		-F|--force)
		force=1
		shift
		;;
		-m=*|--mode=*)
		mode="${i#*=}"
		shift
		;;
		-o=*|--output=*)
		if [ "${i#*=}" == "STDOUT" ] || [ "${i#*=}" == "stdout" ];then
			output="stdout"
		else
			output="file"
			outputFile="$(SanitizeFilePath "${i#*=}")"
		fi
		shift
		;;
		-p=*|--permission=*)
		permission="${i#*=}"
		shift
		;;
		--debug)
		debug=1
		shift
		;;
		*)
		echo "Unknown arg supplied. The failing arg is '$i'"
		exitw 4
		shift
		;;
	esac
done

if [ ! -f "$file" ];then
	echo "The file you supplied, '$file', can not be found or is not a file."
	exitw 3
fi
if [ -f "$outputFile" ];then
	if [ "$force" != 1 ];then
		echo "A file already exists in output path, would you like to overwrite it? Press [y]es or [n]o"
		read continue
		if [ "$continue" != "y" ] && [ "$continue" != "Y" ];then
			exitw 2
		else
			echo "Continuing..."
			unset continue
		fi
	fi
	fi
if [ "$force" != 1 ];then
	if [ "$(head -1 "$file")" != '#!/bin/bash' ] && [ "$(head -1 "$file")" != '#!/bin/sh' ] && [ "$(head -1 "$file")" != '#!/usr/bin/env bash' ];then
		echo "The script targeted might not be a bash script, would you still like to continue? Press [y]es or [n]o"
		read continue
		if [ "$continue" != "y" ] && [ "$continue" != "Y" ];then
			exitw 2
		else
			echo "Continuing..."
			unset continue
		fi
	fi
fi

# Minify
FirstLine="$(readLine 1)"
body=""
line=2
linesInFile=$(wc -l < "$file")

while [ $(($line-1)) -le $linesInFile ];do
	if [ "$debug" == "1" ];then
		echo $line
	fi
	processed="$(processData "$(readLine $line)")"
	# If this line is a case terminator ';;', remove trailing ; from body
	if [ "$processed" == ";;" ] && [ "${body: -1}" == ";" ];then
		body="${body:0:${#body}-1}"
	fi
	body+="$processed"
	line=$((line+1))
done

fullfile="$(printf '%s\n' "$FirstLine"; printf '%s' "$body")"

if [ "$output" == "stdout" ];then
	printf '%s' "$fullfile"
elif [ "$output" == "file" ];then
	printf '%s' "$fullfile" > "$outputFile"
	chmod "$permission" "$outputFile"
else
	exitw 6
fi

exit
