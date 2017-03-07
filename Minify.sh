#!/bin/bash 
# License: The MIT License (MIT)
# Author Zuzzuc https://github.com/Zuzzuc/

# This script will Minify bash scripts.


# Exit codes for this script
# 0: Everything went well
# 1: Unknown error
# 2: User declined to continue when warned about script content
# 3: File does not exist
# 4: Unknown argument supplied to script
# 5: This script will not minify itself
# 6: Unknown output mode encounterd


# Supported arguments
#
# File argument, chooses what file to be minified 
# Used with a parameter
# This argument is REQUIRED for this script to work.
# -f or --file
# example: ./script.sh -f=test.txt
#
# Force argument, if enabled does not check if file really is a bash script.
# Should not be supplied with a parameter
# This argument is not required for the script to work
# -F or --force
# example: ./script.sh -F
#
# Mode argument, chooses what mode to use. 
# Used with a parameter
# This argument is not required for the script to work
# -m or --mode
# example: ./script.sh --mode=default
# Output argument, chooses how to handle result returned by this script
#

# Different modes
# Default mode is RAM
# Used with a parameter
#
# RAM
# This mode will load the whole script into RAM, and then making the changes while its there, and in the end it will output-.
# This is the fasterst, and for now the only, mode.
#

# Different outputs
# Default output is STDOUT
# Used with a parameter
# -o or --output
# This argument is not required for the script to work
#
# STDOUT
# This parameter will cause the output to go into stdout.
# This makes it so you can get the content of a minified script from a console, without first putting it into a file.
# E.G, you can do the following
## SomeVar="$(./Script -f=Somefile.txt -o=STDOUT)" ##																																														 
#
# To output to a file, specify the file after -o=.
# Example: ./Script -f=Somefile.sh -o=SomeOtherfile.sh

# Different permissions
# Default permission is u+x
# Used with a parameter
# This argument is not required for the script to work
# -p or --permission
#
# The given permission will be applied to the output file.
# Example: ./Script -f=Somefile.sh -o=SomeOtherfile.sh -p="u-r"



# Assign variables 
# Default vars
force=0 
permission="u+x"
mode=RAM # RAM is deafault
self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

#Functions

exitw(){
	# Exit, and output error code.
	# Usage is $1, where $1 is the error code.
	echo "Error code: $1. Exiting"
	exit $1
}

SanitizeFilePath(){
	# This function will remove \ and space at the end of a filepath to make it parse well into other, quoted, functions/commands
	# Usage $1, where $1 is a file path.
	echo "$(echo $(echo "$1" | sed 's%\\%%g')|sed -e 's%[[:space:]]*$%%')"
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
	data=$(echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	
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
	
	# We should not run this is data is a comment, as it will corrupt the script.
	if [ $ic -eq 0 ];then
		# Look for exceptions
		if [ "${data: -3}" == ";do" ] || [ "${data: -5}" == ";then" ] || [ "${data: -4}" == "else" ] || [ "${data: -4}" == "elif" ] || [ "${data: -1}" == "{" ];then
			# Add a space
			data="$(echo "$data" | sed "s%$% %")"	
		elif [ "${data: -1}" == "}" ];then
			data=$(echo "$data" | sed 's%}$% };%')
		else
			# Add ';' to end of line. 
			data="$(echo "$data" | sed "s%$%;%")"
		fi
	fi
		
	# Return $data
	echo -ne "$data"
	
}

# Handle input
for i in "$@";do
	case $i in
		$self)
    	shift
    	;;
    	-f=*|--file=*)
   		file=$(SanitizeFilePath "$(echo "${i#*=}")") 		
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
    	*)
    	echo "Unknown arg supplied. The failing arg is '$i'"
    	exitw 4
    	shift
   		;;
	esac
done

if [ ! -f "$file" ];then
	echo "The file you supplies, '$file', can not be found or is not a file."
	exitw 3
fi
if [ "$force" != 1 ];then
	if [ "$(head -1 "$file")" != '#!/bin/bash' ] && [ "$(head -1 "$file")" != '#!/bin/sh' ] && [ "$(head -1 "$file")" != '#!/usr/bin/env bash' ];then
		echo "The script targeted might not be a bash script, would you still like to continue? Press [y]es or [n]o"
		read continue
		echo it is $continue
		if [ "$continue" != "y" ] && [ "$continue" != "Y" ];then
			exitw 2
		else
			echo "Continuing..."
		fi
	fi
fi

FirstLine="$(echo -e "$(readLine 1)\n")"
body=""
line=2 # Skip line 1
linesInFile=$(wc -l < "$file")

while [ $(($line-1)) -le $linesInFile ];do
	echo $line
	body+="$(processData "$(readLine $line)")"
	line=$((line+1))
done

fullfile=$(echo $FirstLine;echo $body)

if [ "$output" == "stdout" ];then
	echo "$fullfile"
elif [ "$output" == "file" ];then
	echo "$fullfile" > "$outputFile"
	chmod "$permission" "$outputFile"
else
	exitw 6
fi

exit