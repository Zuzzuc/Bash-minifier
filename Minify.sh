#!/usr/bin/env bash
# License: The MIT License (MIT)
# Author Zuzzuc https://github.com/Zuzzuc/

# Default variables
force=0
permission="u+x"
output=stdout
debug=0
self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Parse arguments
for i in "$@"; do
	case $i in
		"$self") shift ;;
		-f=*|--file=*)
			file="${i#*=}"
			file="${file%\\}"
			file="${file%"${file##*[![:space:]]}"}"
			if [ "$file" == "$self" ]; then
				echo "You are trying to execute this script on itself."
				echo "Error code: 5. Exiting"; exit 5
			fi
			shift ;;
		-F|--force) force=1; shift ;;
		-o=*|--output=*)
			if [ "${i#*=}" == "STDOUT" ] || [ "${i#*=}" == "stdout" ]; then
				output="stdout"
			else
				output="file"
				output_file="${i#*=}"
				output_file="${output_file%\\}"
				output_file="${output_file%"${output_file##*[![:space:]]}"}"
			fi
			shift ;;
		-p=*|--permission=*) permission="${i#*=}"; shift ;;
		--debug) debug=1; shift ;;
		*)
			echo "Unknown arg supplied. The failing arg is '$i'"
			echo "Error code: 4. Exiting"; exit 4
			;;
	esac
done

# Validate input file
if [ ! -f "$file" ]; then
	echo "The file you supplied, '$file', can not be found or is not a file."
	echo "Error code: 3. Exiting"; exit 3
fi

# Check output file
if [ -f "$output_file" ] && [ "$force" != 1 ]; then
	echo "A file already exists in output path, would you like to overwrite it? Press [y]es or [n]o"
	read continue
	if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
		echo "Error code: 2. Exiting"; exit 2
	fi
	echo "Continuing..."
fi

# Check if it looks like a bash script
if [ "$force" != 1 ]; then
	firstline="$(head -1 "$file")"
	if [ "$firstline" != '#!/bin/bash' ] && [ "$firstline" != '#!/bin/sh' ] && [ "$firstline" != '#!/usr/bin/env bash' ]; then
		echo "The script targeted might not be a bash script, would you still like to continue? Press [y]es or [n]o"
		read continue
		if [ "$continue" != "y" ] && [ "$continue" != "Y" ]; then
			echo "Error code: 2. Exiting"; exit 2
		fi
		echo "Continuing..."
	fi
fi

####### State-aware minifier #################################################

lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
done < "$file"
total=${#lines[@]}

shebang="${lines[0]}"
body=""

# State carried across lines
in_squote=0
in_dquote=0
in_heredoc=0
heredoc_delim=""
pending_heredocs=()
needs_newline=0 	# set after heredoc ends, so next line gets \n prefix

# Decide what separator to append after a processed line
emit_line() {
	local ln="$1"

	# Trim leading whitespace
	ln="${ln#"${ln%%[![:space:]]*}"}"
	# Trim trailing whitespace
	ln="${ln%"${ln##*[![:space:]]}"}"

	# Skip empty lines
	[[ -z "$ln" ]] && return

	# After a heredoc, the next statement must start on a new line
	if [[ $needs_newline -eq 1 ]]; then
		body+=$'\n'
		needs_newline=0
	fi

	# 1. Backslash continuation
	if [[ "${ln: -1}" == "\\" ]]; then
		ln="${ln%\\}"
		ln="${ln%"${ln##*[![:space:]]}"}"
		body+="$ln "
		return
	fi

	# 2. Implicit continuation: line ends with |  &&  ||
	if [[ "${ln: -1}" == "|" ]] || [[ "${ln: -2}" == "&&" ]] || [[ "${ln: -2}" == "||" ]]; then
		body+="$ln "
		return
	fi

	# 3. Keywords that need a trailing space
	if [[ "${ln: -5}" == ";then" ]] || [[ "$ln" =~ (^|[[:space:]])then$ ]] ||
	   [[ "${ln: -3}" == ";do" ]]   || [[ "$ln" =~ (^|[[:space:]])do$ ]] ||
	   [[ "$ln" =~ (^|[[:space:]])else$ ]] ||
	   [[ "$ln" =~ (^|[[:space:]])elif$ ]] ||
	   [[ "$ln" =~ (^|[[:space:]])\{$ ]] ||
	   [[ "$ln" =~ (^|[[:space:]])in$ ]]; then
		body+="$ln "
		return
	fi

	# 4. Case pattern: unbalanced ), no ;; && ||
	if [[ "${ln: -1}" == ")" ]]; then
		local opens=0 closes=0 k ch
		for (( k=0; k<${#ln}; k++ )); do
			ch="${ln:$k:1}"
			[[ "$ch" == "(" ]] && (( opens++ ))
			[[ "$ch" == ")" ]] && (( closes++ ))
		done
		if (( closes > opens )) && ! [[ "$ln" =~ \;\;|\&\&|\|\| ]]; then
			body+="$ln "
			return
		fi
	fi

	# 5. Case terminator ;;
	if [[ "${ln: -2}" == ";;" ]]; then
		if [[ "$ln" == ";;" ]]; then
			# Standalone ;; remove trailing ; from previous statement
			[[ "${body: -1}" == ";" ]] && body="${body:0:${#body}-1}"
		fi
		body+="$ln"
		return
	fi

	# 6. Closing brace }
	if [[ "$ln" =~ (^|[[:space:]\;])\}$ ]]; then
		body+="${ln%\}} };"
		return
	fi

	# 7. Default: semicolon
	body+="$ln;"
}

#### Main loop ####
for (( idx=1; idx<total; idx++ )); do
	raw="${lines[$idx]}"

	[[ "$debug" == "1" ]] && echo "LINE $((idx+1)): sq=$in_squote dq=$in_dquote hd=$in_heredoc" >&2

	# Inside a heredoc, pass through verbatim
	if [[ $in_heredoc -eq 1 ]]; then
		h_trim="${raw#"${raw%%[![:space:]]*}"}"
		h_trim="${h_trim%"${h_trim##*[![:space:]]}"}"
		body+=$'\n'"$raw"
		if [[ "$h_trim" == "$heredoc_delim" ]]; then
			in_heredoc=0
			heredoc_delim=""
			if [[ ${#pending_heredocs[@]} -gt 0 ]]; then
				heredoc_delim="${pending_heredocs[0]}"
				pending_heredocs=("${pending_heredocs[@]:1}")
				in_heredoc=1
			else
				needs_newline=1
			fi
		fi
		continue
	fi

	# Start any heredocs queued from the previous line
	if [[ ${#pending_heredocs[@]} -gt 0 ]]; then
		heredoc_delim="${pending_heredocs[0]}"
		pending_heredocs=("${pending_heredocs[@]:1}")
		in_heredoc=1
		body+=$'\n'"$raw"
		h_trim="${raw#"${raw%%[![:space:]]*}"}"
		h_trim="${h_trim%"${h_trim##*[![:space:]]}"}"
		if [[ "$h_trim" == "$heredoc_delim" ]]; then
			in_heredoc=0
			heredoc_delim=""
			if [[ ${#pending_heredocs[@]} -gt 0 ]]; then
				heredoc_delim="${pending_heredocs[0]}"
				pending_heredocs=("${pending_heredocs[@]:1}")
				in_heredoc=1
			else
				needs_newline=1
			fi
		fi
		continue
	fi

	# Character-by-character scan
	clean=""
	len=${#raw}
	line_continuation=0

	for (( pos=0; pos<len; pos++ )); do
		c="${raw:$pos:1}"

		if [[ $in_squote -eq 1 ]]; then
			clean+="$c"
			[[ "$c" == "'" ]] && in_squote=0

		elif [[ $in_dquote -eq 1 ]]; then
			if [[ "$c" == "\\" ]]; then
				if (( pos+1 < len )); then
					# Escaped char inside double quotes, take both
					clean+="$c"
					(( pos++ ))
					clean+="${raw:$pos:1}"
				else
					# Backslash at end of line inside double quotes = line continuation
					line_continuation=1
				fi
			elif [[ "$c" == '"' ]]; then
				clean+="$c"
				in_dquote=0
			else
				clean+="$c"
			fi

		else
			# NORMAL state
			if [[ "$c" == "'" ]]; then
				in_squote=1
				clean+="$c"

			elif [[ "$c" == '"' ]]; then
				in_dquote=1
				clean+="$c"

			elif [[ "$c" == "\\" ]] && (( pos+1 < len )); then
				clean+="$c"
				(( pos++ ))
				clean+="${raw:$pos:1}"

			elif [[ "$c" == "#" ]]; then
				# Comment only if at word boundary
				if [[ ${#clean} -eq 0 ]]; then
					tmp_trimmed="${clean#"${clean%%[![:space:]]*}"}"
					if [[ -z "$tmp_trimmed" ]]; then
						break
					else
						clean+="$c"
					fi
				else
					prev="${clean: -1}"
					if [[ "$prev" =~ [[:space:]\;\|\&\(] ]]; then
						clean="${clean%"${clean##*[![:space:]]}"}"
						break
					else
						clean+="$c"
					fi
				fi

			elif [[ "$c" == "<" ]] && (( pos+1 < len )) && [[ "${raw:$((pos+1)):1}" == "<" ]]; then
				# Heredoc
				clean+="<<"
				(( pos++ ))
				if (( pos+1 < len )) && [[ "${raw:$((pos+1)):1}" == "-" ]]; then
					clean+="-"
					(( pos++ ))
				fi
				# Skip whitespace
				while (( pos+1 < len )) && [[ "${raw:$((pos+1)):1}" =~ [[:space:]] ]]; do
					(( pos++ ))
					clean+="${raw:$pos:1}"
				done
				(( pos++ ))
				local_delim=""
				if (( pos < len )); then
					quote_c="${raw:$pos:1}"
					if [[ "$quote_c" == "'" || "$quote_c" == '"' ]]; then
						clean+="$quote_c"
						(( pos++ ))
						while (( pos < len )) && [[ "${raw:$pos:1}" != "$quote_c" ]]; do
							local_delim+="${raw:$pos:1}"
							clean+="${raw:$pos:1}"
							(( pos++ ))
						done
						(( pos < len )) && clean+="${raw:$pos:1}"
					elif [[ "$quote_c" == "\\" ]]; then
						(( pos++ ))
						while (( pos < len )) && [[ "${raw:$pos:1}" =~ [a-zA-Z0-9_] ]]; do
							local_delim+="${raw:$pos:1}"
							clean+="${raw:$pos:1}"
							(( pos++ ))
						done
						(( pos-- ))
					else
						while (( pos < len )) && [[ "${raw:$pos:1}" =~ [a-zA-Z0-9_] ]]; do
							local_delim+="${raw:$pos:1}"
							clean+="${raw:$pos:1}"
							(( pos++ ))
						done
						(( pos-- ))
					fi
				fi
				[[ -n "$local_delim" ]] && pending_heredocs+=("$local_delim")

			else
				clean+="$c"
			fi
		fi
	done

	# Multi-line string, preserve newline (unless line continuation)
	if [[ $in_squote -eq 1 ]] || [[ $in_dquote -eq 1 ]]; then
		if [[ $line_continuation -eq 1 ]]; then
			body+="$clean"
		else
			body+="$clean"$'\n'
		fi
		continue
	fi

	# If this line starts a heredoc, emit with newline
	if [[ ${#pending_heredocs[@]} -gt 0 ]]; then
		local_ln="$clean"
		local_ln="${local_ln#"${local_ln%%[![:space:]]*}"}"
		local_ln="${local_ln%"${local_ln##*[![:space:]]}"}"
		if [[ -n "$local_ln" ]]; then
			if [[ $needs_newline -eq 1 ]]; then
				body+=$'\n'
				needs_newline=0
			fi
			body+="$local_ln"
		fi
	else
		emit_line "$clean"
	fi
done

# Assemble output
fullfile="$(printf '%s\n' "$shebang"; printf '%s' "$body")"

if [[ "$output" == "stdout" ]]; then
	printf '%s' "$fullfile"
elif [[ "$output" == "file" ]]; then
	printf '%s' "$fullfile" > "$output_file"
	chmod "$permission" "$output_file"
else
	echo "Error code: 6. Exiting"; exit 6
fi

exit 0
