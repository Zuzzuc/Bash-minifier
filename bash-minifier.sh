#!/usr/bin/env bash
# License: The MIT License (MIT)
# Author Zuzzuc https://github.com/Zuzzuc/

# Runs on bash 3.2 and newer
if [ -z "$BASH_VERSION" ] || [ "${BASH_VERSINFO[0]}" -lt 3 ] || { [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  echo "bash-minifier needs bash 3.2 or newer (this is ${BASH_VERSION:-not bash})." >&2
  exit 1
fi

# The parser matches frame types with patterns like @(a|b) inside [[ ]].
# bash 4.1+ allows that by default. bash 3.2 needs extglob
shopt -s extglob

# Helps with performance for the parser
LC_ALL=C

# Default variables
force=0
permission="u+x"
output=stdout
debug=0
verify=1
self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
VERSION="2.0.0"

exitw(){  #exitw code message
  local error_code=$1 ; shift;
  if [ $# -gt 0 ];then
    printf '%s\n' "$*" >&2
  fi
  echo "Error code: $error_code. Exiting" >&2
  exit $error_code
}

# Ask a yes/no question. With -f the answer is read from stdin. When the script itself comes on stdin it is read from the terminal instead.
confirm() { #confirm QUESTION
  local answer="" timeout=60 status=0
  echo "$1 Press [y]es or [n]o (Timeout in ${timeout}s)" >&2
  if [[ -n $file ]]; then
    read -r -t $timeout answer
  elif { exec 3</dev/tty; } 2>/dev/null; then
    read -r -t $timeout answer <&3 ; exec 3<&-
  else
    exitw 2 "Unable to request permission to continue. Use -F to skip this check"
  fi
  [[ $answer == [yY] ]] || exitw 2
  echo "Continuing..." >&2
}

warn() {
  echo "bash-minifier: warning: $*" >&2
}

# Parse arguments
for i in "$@"; do
  case $i in
    "$self") shift ;;
    -f=*|--file=*)
      file="${i#*=}"
      file="${file%\\}"
      file="${file%"${file##*[![:space:]]}"}"
      if [ "$file" == "$self" ]; then
        exitw 5 "You are trying to execute this script on itself."
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
    --no-verify) verify=0; shift ;;
    -V|--version) echo "${VERSION}"; exit 0 ;;
    *) exitw 4 "Unknown arg supplied. The failing arg is '$i'" ;;
  esac
done

# Validate input file
if [ -n "$file" ] && [ ! -f "$file" ]; then
  exitw 3 "The file you supplied, '$file', can not be found or is not a file."
fi

# Check output file
if [ -f "$output_file" ] && [ "$force" != 1 ]; then
  confirm "A file already exists in output path, would you like to overwrite it?"
fi

####### Input #################################################################

# Lines are stored with an explicit index.
# In bash 3.2, arrays are linked lists and lines+=(...) walks the whole list each time.
lines=() ; total=0

# if we give it a file, slurp the file
if [[ -n "$file" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines[total++]=$line
  done < "$file"
# otherwise, attempt to slurp STDIN
else
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines[total++]=$line
  done
fi

# Don't parse the first line if it's a shebang
if [[ ${lines[0]} == '#!'* ]]; then
  shebang="${lines[0]}" ; first_line=1
else
  shebang="" ; first_line=0
fi
body=""

# Check if it looks like a bash script
if [ "$force" != 1 ]; then
  if [ "$shebang" != '#!/bin/bash' ] && [ "$shebang" != '#!/bin/sh' ] && [ "$shebang" != '#!/usr/bin/env bash' ]; then
    confirm "The script targeted might not be a bash script, would you still like to continue?"
  fi
fi

####### Stack-based minifier ###############################################
#
# The input is read line by line and scanned character by character. Every construct that can nest ("...", $( ), ${ }, case ... esac, { }, ...) opens a
# FRAME on a stack, and the frame on top decides how characters are read.
#
# Most of the minifying happens at line ends. Each newline is replaced by ";", " " or nothing, depending on the frame and on the LAST TOKEN before it:
#
#   last token        example              newline becomes
#   word              echo hi              ;
#   keyword           then  do  {  in      (space)
#   continue          |  &&  ||  |&        (space)
#   funchead          f()                  (space)
#   end               ;;  ;&  ;;&          (nothing)
#   semi / bg         ;  /  &              (nothing, but the
#                                          next token may need a space, see
#                                          read_semicolon and read_angle)
#   open              (  $(                (nothing)
#
# Inside strings, backticks and ${ } newlines are kept as they are.
#
# The ";" is not written right away. It waits in pending_sep and is dropped if the next token is ; ;; & or a closing ), which makes ";;" style duplicates impossible.

# The stack
#
#   stack frame types, innermost last: stack=(top cmdsub dquote)
#   sp: index of the innermost frame in stack (0: only "top" is open)
#   command lists: top  subshell  group  cmdsub  procsub  case  array
#   strings: squote  ansi ($'...')  dquote  backtick  param (${ })
#   arithmetic: arith ($(( )))  arith_cmd ((( )))  arith_bracket ($[ ])
#   paren / bracket: one entry per nested ( or [ inside them
#   patterns: pattern: extglob @( ), [[ =~ (a|b) ]], [[ ( ... ) ]]
#   conditions: dbracket: [[ ... ]] (a newline inside is just a space)

#   stack_line  line each frame was opened on (for warnings)
#   list_state  saved state of the command lists (and [[ ]]) covered by an inner command list. Only command-list frames push/pop here,  stringsand arithmetic don't touch it. ls_sp is its number of entries.
#
# The stacks are indexed with explicit counters rather than [-1]. Negative subscripts need bash 4.3, and bash 3.2 silently reads them as empty.
#
# State of the innermost command list:
#   last: last token kind (see table above)
#   cmd_pos: 1 if the next word is in command position (reserved words like then, {, esac only count there)
#   words: words so far in the current simple command
#   in_word: 1 while inside a word
#   quoted: 1 if the current word has quotes or expansions (then it is never a reserved word)
#   after_for: 1 right after "for"/"select", so "for ((" is arithmetic. 2 right after "for NAME", where "do" is still reserved
#   after_compound: 1 right after fi, done, }, esac, ) ]] or )): bash still accepts closing reserved words there ("[[ x ]] then")
#   after_function: 1 after "function", 2 after "function name"
#   after_coproc: 1 right after "coproc": the next word may be a NAME, and bash still accepts reserved words after it ("coproc N {")
#   case_state: case frames: subject | pattern | body   ("-" otherwise)
#   pattern_start: case frames: 1 at the start of a pattern list

stack=(top) ; stack_line=(1) ; sp=0 ; list_state=() ; ls_sp=0
top=top # copy of ${stack[sp]}, the innermost frame type (kept for speed)
last=open ; cmd_pos=1 ; words=0 ; in_word=0 ; quoted=0
after_for=0 ; after_function=0 ; case_state=- ; pattern_start=0 ; after_compound=0

# Special characters. A run of anything else is copied in one go.
LIST_SPECIAL=$' \t#\'"`$;&|<>()\\'
DQUOTE_SPECIAL='\"$`'
ANSI_SPECIAL=$'\\\''
BACKTICK_SPECIAL='\`'
# NAME= / NAME+= / NAME[i]= directly followed by ( starts an array.
ASSIGNMENT_RE='^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*])?\+?=$'

out=""  # The minified output of the current input line
done_out="" # The minified output of all earlier lines
done_last=""  # The last character of done_out
# Appending to a long string copies it, and bash 3.2 does that several times slower than bash 5. So the output is built per line in the short "out" and moved into done_out once per line (flush_out).
pending_sep="" # What the last newline owes: "", " " or ";"
ws="" # Whitespace between tokens, held back until needed
continued=0 # 1 if the line ended with a backslash continuation
word="" # Text of the current (unquoted) word
word_cmd_pos=0 # If the current word was in command position
word_after_compound=0 # If the current word started right after a compound command
after_coproc=0 ; word_after_coproc=0 # See after_coproc above
func_candidate=0 # Last word could be a function name
parse_affecting=0 # This line ran shopt/(un)alias. They change how LATER lines are parsed, so the line must end with a real newline
bare_time=0 # The last tokens were a bare "time" or "time -p" (or that plus ";"). bash 3.2 reads "time;" as a whole command. Such a line also ends with a real newline
word_after_time=0 # If the current word started right after a bare "time"
kw_depth=0 # if/while/until/for/select not yet closed by fi/done, in the current command list (saved and restored with it)
line="" ; pos=0 ; len=0 ; line_no=0

# Parse units
#
# Bash reads a script one top-level command at a time: it parses everything up to a newline outside any compound command, runs it, then parses the next one.
# Joining two top-level lines with ";" therefore makes bash parse the second before the first has run. That is fine unless the first changes how
# the second is parsed: shopt -s extglob (possibly inside a function, a sourced file or eval) must have run before a pattern like @(a|b) is parsed, and an
# alias must be defined before the line that uses it is parsed.
#
# So the output of the current top-level command ("parse unit") is held back in "held", together with the separator in front of it in "held_sep". While
# the unit is not finished, that separator can still be turned back into the original newline (need_parse_boundary). This costs no bytes when the
# separator was ";" and one byte when it was nothing (after "a &" or "a;").
#
#   held_sep: Separator before the current unit: ";", "" or a newline
#   held_brk: 1 if the original had a newline there (so one may be put back)
#   held: The unit's output from earlier lines (out holds the current line)
#   held_last: Last character of held
#   top_boundary: Set at a top-level newline, the next token starts a new unit. 2 if a real newline is already there (after a heredoc body)
#   aliases_on: the script defines an alias or enables expand_aliases: from then on, every top-level newline is kept
held="" ; held_last="" ; held_sep="" ; held_brk=0 ; top_boundary=0 ; aliases_on=0
held_len=0          # length of held (kept up to date, as ${#held} is slow)
#
# Command substitutions and process substitutions are parsed the same way when they run: their text is read one command at a time, so a newline at their
# top level is a parse unit boundary too ("setup" + newline + "e hi" inside $( ) needs the newline if setup defines the alias e). Their units
# cannot be held back like the top level's, because they are part of it, so the position of the separator in front of the current unit is remembered
# instead (per frame, indexed like stack) and patched if needed:
#
#   cs_kind: "" (no separator yet), ";" (a ";" at cs_off), ins (nothing at cs_off; a newline may be inserted there) or nl (already a newline)
#   cs_off: Position of the separator, counted from the start of held
#   cs_done: 1 once the separator has been turned into a newline
#   cs_boundary: Like top_boundary, for the innermost substitution
cs_kind=() ; cs_off=() ; cs_done=() ; cs_boundary=0
word_start=0 ; word_line=0  # Where the current word starts in out, and on which line
cmd_first=""  # First word of the current simple command, without quotes

heredoc_delims=() ; heredoc_strip=() ; heredoc_quoted=() ; heredoc_index=0 ; heredoc_active=0
heredoc_logical="" # Unquoted heredoc: body text joined so far by \+newline
heredoc_cont=0 # 1 if the previous body line ended with \+newline

# --- Stack ------------------------------------------------------------------

push_frame() {   # push_frame TYPE
  (( sp++ )) ; stack[sp]=$1 ; stack_line[sp]=$line_no ; top=$1
  [[ $1 == @(cmdsub|procsub) ]] && { cs_kind[sp]="" ; cs_done[sp]=0 ; }
  if [[ $1 == @(top|subshell|group|cmdsub|procsub|case|array|dbracket) ]]; then
    # The new list covers the current one, save its state and start fresh.
    list_state[ls_sp]="$last $cmd_pos $words $in_word $quoted $after_for $after_function $case_state $pattern_start $after_compound $kw_depth"
    (( ls_sp++ ))
    last=open ; cmd_pos=1 ; words=0 ; in_word=0 ; quoted=0
    after_for=0 ; after_function=0 ; case_state=- ; pattern_start=0 ; after_compound=0
    kw_depth=0
  fi
  func_candidate=0
}

pop_frame() {
  local closed=$top saved_state
  (( sp > 0 )) || return 1
  unset "stack[sp]" "stack_line[sp]"
  (( sp-- ))
  top=${stack[sp]}
  if [[ $closed == @(top|subshell|group|cmdsub|procsub|case|array|dbracket) ]]; then
    # Back in the covering list, restore its state.
    (( ls_sp-- ))
    saved_state=(${list_state[ls_sp]})
    unset "list_state[ls_sp]"
    last=${saved_state[0]} ; cmd_pos=${saved_state[1]} ; words=${saved_state[2]}
    in_word=${saved_state[3]} ; quoted=${saved_state[4]} ; after_for=${saved_state[5]}
    after_function=${saved_state[6]} ; case_state=${saved_state[7]} ; pattern_start=${saved_state[8]}
    after_compound=${saved_state[9]} ; kw_depth=${saved_state[10]}
  fi
  func_candidate=0
}

describe_frame() {
  case $1 in
    subshell) echo "subshell ( )" ;;
    group)    echo "group { }" ;;
    cmdsub)   echo "command substitution \$( )";;
    procsub)  echo "process substitution <( )" ;;
    case)     echo "case ... esac" ;;
    array)    echo "array ( )" ;;
    squote)   echo "single quote" ;;
    ansi)     echo "\$'...' string" ;;
    dquote)   echo "double quote" ;;
    backtick) echo "backtick" ;;
    param)    echo "parameter expansion \${ }" ;;
    arith|arith_cmd|paren|arith_bracket|bracket) echo "arithmetic" ;;
    pattern)  echo "parenthesized pattern ( )" ;;
    dbracket) echo "[[ ]] condition" ;;
    *)        echo "$1" ;;
  esac
}

stack_string() {
  local IFS='>'
  echo "${stack[*]}"
}



# --- Output helpers ---------------------------------------------------------

# Move the current line's output to the current parse unit.
flush_out() {
  [[ -n $out ]] || return 0
  (( held_len += ${#out} ))
  held_last=${out: -1} ; held+=$out ; out=""
}

# Set lc to the last character written so far (possibly on an earlier line).
set_last_char() {
  if [[ -n $out ]]; then
    lc=${out: -1}
  elif [[ -n $held ]]; then
    lc=$held_last
  elif [[ -n $held_sep ]]; then
    lc=${held_sep: -1}
  else
    lc=$done_last
  fi
}

# A new top-level command starts, the previous parse unit is final.
start_parse_unit() {
  local text=$held_sep$held$out
  if [[ -n $text ]]; then
    done_out+=$text ; done_last=${text: -1}
  fi
  held="" ; held_last="" ; held_len=0 ; out=""
  if (( top_boundary == 2 )); then
    held_sep="" ; held_brk=0
  else
    held_sep=$pending_sep ; held_brk=1
  fi
  pending_sep="" ; top_boundary=0
  (( aliases_on )) && need_parse_boundary
}

# The current parse unit must be parsed only after everything before it has run, put back the newline the original had in front of it.
# That is the current top-level command, and the current command of every enclosing $( ) or <( ) (innermost first, so an insertion never moves a separator that is still to be patched).
need_parse_boundary() {
  local i k kind
  for (( i = sp; i > 0; i-- )); do
    [[ ${stack[i]} == @(cmdsub|procsub) ]] || continue
    kind=${cs_kind[i]}
    [[ $kind == ';' || $kind == ins ]] || continue
    (( cs_done[i] )) && continue
    cs_done[i]=1 ; k=${cs_off[i]}
    if (( k >= held_len )); then  # on the current line
      (( k -= held_len ))
      if [[ $kind == ins ]]; then
        out=${out:0:k}$'\n'${out:k}
      elif [[ ${out:k:1} == ';' ]]; then
        out=${out:0:k}$'\n'${out:k+1}
      fi
    else  # on an earlier line
      if [[ $kind == ins ]]; then
        held=${held:0:k}$'\n'${held:k} ; (( held_len++ ))
      elif [[ ${held:k:1} == ';' ]]; then
        held=${held:0:k}$'\n'${held:k+1}
      fi
      held_last=${held: -1}
    fi
  done
  (( held_brk )) && held_sep=$'\n'
  return 0
}

# A new command starts at the top level of a $( ) or <( ): remember where the separator in front of it goes, so it can become a newline later.
start_sub_unit() {
  if (( cs_boundary == 2 )) || [[ $pending_sep == $'\n' ]]; then
    cs_kind[sp]=nl
  elif (( aliases_on )); then
    pending_sep=$'\n' ; cs_kind[sp]=nl
  else
    if [[ $pending_sep == ';' ]]; then
      cs_kind[sp]=';'
    else
      cs_kind[sp]=ins
    fi
    cs_off[sp]=$(( held_len + ${#out} )) ; cs_done[sp]=0
  fi
  cs_boundary=0
}

# Write what the last newline owes, then any held-back whitespace.
emit_pending() {
  (( top_boundary )) && start_parse_unit
  (( cs_boundary )) && start_sub_unit
  out+="$pending_sep$ws"
  pending_sep="" ; ws="" ; bare_time=0
}

# Same, but a pending ";" is dropped. The next char ends the command itself.
emit_pending_drop_semicolon() {
  [[ $pending_sep == ";" ]] && pending_sep=""
  cs_boundary=0 # ) ; & end a command, they do not start a new one
  emit_pending
  func_candidate=0
}

# --- Words and reserved words -----------------------------------------------

start_word() {   # start_word FIRST_CHAR
  (( in_word )) && return
  # A "}" right after a newline-turned-";" gets a space: "return 0; }"
  [[ $1 == "}" && $pending_sep == ";" ]] && pending_sep="; "
  word_after_time=$bare_time
  emit_pending
  word_start=${#out} ; word_line=$line_no
  in_word=1 ; quoted=0
  word="" ; word_cmd_pos=$cmd_pos ; func_candidate=0
  word_after_compound=$after_compound ; after_compound=0
  word_after_coproc=$after_coproc ; after_coproc=0
}

# After fi, done, }, esac or a closing ( ) the command is complete.
after_close() {
  in_word=0 ; last=word ; cmd_pos=0 ; words=1
  func_candidate=0 ; after_compound=1 ; after_coproc=0
}

end_word() {
  (( in_word )) || return 0
  in_word=0

  if [[ $top == array ]]; then
    last=word
    return
  fi

  # Inside [[ ]] there are no reserved words
  if [[ $top == dbracket ]]; then
    if (( !quoted )) && [[ $word == ']]' ]]; then
      pop_frame ; after_close
    else
      last=word ; cmd_pos=0
    fi
    return
  fi

  # case SUBJECT in PATTERN) BODY ;; ... esac
  if [[ $top == case ]] && [[ $case_state == subject ]]; then
    if (( words >= 1 && !quoted )) && [[ $word == in ]]; then
      case_state=pattern ; pattern_start=1
      last=keyword ; cmd_pos=0
    else
      (( words++ )) ; last=word
    fi
    return
  fi
  if [[ $top == case ]] && [[ $case_state == pattern ]]; then
    if (( pattern_start && !quoted )) && [[ $word == esac ]]; then
      pop_frame ; after_close
    else
      pattern_start=0 ; last=word
    fi
    return
  fi

  # "for NAME do" without "in", "do" is reserved right after the name.
  if (( after_for == 2 && !quoted )) && [[ $word == do ]]; then
    last=keyword ; cmd_pos=1 ; after_for=0
    return
  fi

  # Reserved words that end or continue a compound command. They count in command position and also right after another compuond command.
  # "[[ x ]] then", "(( i )) do", "done }", "fi esac", "for (( ... )) {".
  if (( !quoted && (word_cmd_pos || word_after_compound) )); then
    case $word in
      'then'|'else'|'elif'|'do')
        last=keyword ; cmd_pos=1 ; after_function=0 ; after_for=0
        return ;;
      '{')
        after_function=0 ; push_frame group ; last=keyword
        return ;;
      '}')
        if [[ $top == group ]]; then pop_frame ; after_close ; return ; fi ;;
      'fi'|'done')
        (( kw_depth -= kw_depth > 0 )) ; after_close ; return ;;
      'esac')
        if [[ $top == case ]]; then pop_frame ; after_close ; return ; fi ;;
    esac
  fi

  # Reserved words that start a command in command position only.
  if (( !quoted && word_cmd_pos )); then
    case $word in
      'if'|'while'|'until')
        last=keyword ; cmd_pos=1 ; after_function=0 ; (( kw_depth += 1 ))
        return ;;
      '!')
        last=keyword ; cmd_pos=1 ; after_function=0
        return ;;
      'time')
        # Like the words above, but "time" alone on a line is complete. Its newline must not become a space and not ";" either
        # which bash 3.2 rejects before another command. It stays a real newline (see bare_time).
        last=word ; cmd_pos=1 ; after_function=0 ; bare_time=1
        return ;;
      '[[')
        push_frame dbracket ; cmd_pos=0 ; last=keyword
        return ;;
      'case')
        push_frame case ; case_state=subject ; cmd_pos=0 ; last=word
        return ;;
      'for'|'select')
        last=word ; cmd_pos=0 ; after_for=1 ; words=1 ; (( kw_depth += 1 )) ; cmd_first=""
        return ;;
      'coproc')
        last=keyword ; cmd_pos=1 ; after_coproc=1
        return ;;
      'function')
        last=word ; cmd_pos=0 ; after_function=1 ; words=1 ; cmd_first=""
        return ;;
    esac
  fi

  # The name after "function". A body is expected next.
  if (( after_function == 1 )); then
    after_function=2 ; cmd_pos=1 ; last=funchead ; words=1
    return
  fi

  # An ordinary word.
  (( words++ ))
  cmd_pos=0 ; last=word ; after_function=0
  (( word_after_coproc )) && cmd_pos=1     # "coproc NAME {": { is reserved
  if (( word_after_time && !quoted )) && [[ $word == -p ]]; then   # "time -p"
    bare_time=1 ; cmd_pos=1
  fi
  (( after_for = after_for == 1 ? 2 : 0 ))   # "for NAME": see "do" above
  (( word_cmd_pos && words == 1 && !quoted )) && func_candidate=1
  # Commands that change how later lines are parsed: shopt, alias, unalias, also as \alias, 'shopt', builtin alias, command alias.
  # An alias definition or expand_aliases anywhere (even in a function or an eval string) means aliases may be in use. From here on every newline between commands is kept (see "Parse units").
  if (( words == 1 )) || [[ $cmd_first == @(builtin|command|shopt|eval) ]]; then
    local name=$word
    if (( quoted )); then
      name=""
      (( word_line == line_no )) && name=${out:word_start}
      name=${name//[\"\'\\]/}
    fi
    if (( words == 1 && word_cmd_pos )) || [[ $cmd_first == @(builtin|command) && $words == 2 ]]; then
      [[ $name == @(shopt|alias|unalias) ]] && parse_affecting=1
      [[ $name == alias ]] && aliases_on=1
    fi
    (( words == 1 )) && cmd_first=$name
    [[ $name == *expand_aliases* ]] && aliases_on=1
    [[ $cmd_first == eval && $name == *alias* ]] && aliases_on=1
  fi
  return 0
}

# Copy one ordinary character as part of a word.
word_char() {
  start_word "$1"
  out+=$1 ; word+=$1 ; (( pos++ ))
}

# --- Openers that can appear in several frames ------------------------------

# "$((" and "((" are ambiguous. They are arithmetic only if the  ")" that closes the second "(" is immediately followed by another ")".
# Otherwise "$((cmd) | x)" is "$( (cmd) | x)" and "((cmd) | x)" is "( (cmd) | x)". This looks ahead from position $1 on the current line,
# continuing on later lines if needed. Unresolved at end of input = arithmetic.
closes_as_arithmetic() {
  local l=$idx p=$1 text=$line n c depth=0 quote="" dollar=0
  while :; do
    n=${#text}
    while (( p < n )); do
      c=${text:p:1}
      if [[ -n $quote ]]; then  # inside '...', $'...', "..." or `...`
        if [[ $c == \\ && $quote != "'" ]]; then
          (( p+=2 ))
          continue
        fi
        [[ $c == "${quote: -1}" ]] && quote=""  # $'...' ends at '
        (( p++ )) ; continue
      fi
      case $c in
        \\)       (( p+=2 )) ; dollar=0 ; continue ;;
        "'")      if (( dollar )); then quote="\$'" ; else quote=$c ; fi ;;
        '"'|'`')  quote=$c ;;
        '(')      (( depth++ )) ;;
        ')')
          if (( depth > 0 )); then
            (( depth-- ))
          else
            (( p + 1 < n )) || return 1 # ")" ends the line
            [[ ${text:p+1:1} == ')' ]] ; return
          fi ;;
      esac
      [[ $c == '$' ]] && dollar=1 || dollar=0
      (( p++ ))
    done
    (( ++l < total )) || return 0
    text=${lines[l]} ; p=0 ; dollar=0
  done
}

# At a "$": open the matching expansion, or copy a plain "$".
open_dollar() {
  local next=${line:pos+1:1}
  case $next in
    '(')
      if [[ ${line:pos+2:1} == '(' ]] && closes_as_arithmetic $(( pos + 3 )); then
        out+='$((' ; (( pos+=3 )) ; push_frame arith
      else
        out+='$(' ; (( pos+=2 )) ; push_frame cmdsub
      fi ;;
    '{') out+='${' ; (( pos+=2 )) ; push_frame param ;;
    '[') out+='$[' ; (( pos+=2 )) ; push_frame arith_bracket ;;
    "'"|'"')
      if [[ $top == dquote ]]; then # "$'" and '$"' mean nothing special in "..."
        out+='$' ; (( pos++ ))
      elif [[ $next == "'" ]]; then
        out+="\$'" ; (( pos+=2 )) ; push_frame ansi
      else
        out+='$"' ; (( pos+=2 )) ; push_frame dquote
      fi ;;
    *) out+='$' ; (( pos++ )) ;;
  esac
}

# Copy a backslash and the character after it.
copy_escape() {
  out+=${line:pos:2} ; (( pos+=2 ))
}

# At "<<" (not "<<<"): copy the operator and delimiter, queue the heredoc.
# Quotes are removed to find the real delimiter.
# The delimiter may be empty (<<'' ends at the first empty line). Any quote or backslash in it makes the body literal, which matters for \+newline.
read_heredoc_operator() {
  local strip=0 delim="" seen=0 quoted_delim=0 ch j
  out+='<<' ; (( pos+=2 ))
  if [[ ${line:pos:1} == '-' ]]; then
    out+='-' ; strip=1 ; (( pos++ ))
  fi
  while (( pos < len )) && [[ ${line:pos:1} == [[:blank:]] ]]; do
    out+=${line:pos:1} ; (( pos++ ))
  done
  while (( pos < len )); do
    ch=${line:pos:1}
    case $ch in
      ' '|$'\t'|';'|'&'|'|'|'('|')'|'<'|'>') break ;;
    esac
    seen=1
    case $ch in
      "'"|'"'|\\) quoted_delim=1 ;;
    esac
    case $ch in
      "'")
        j=$(( pos + 1 ))
        while (( j < len )) && [[ ${line:j:1} != "'" ]]; do delim+=${line:j:1} ; (( j++ )) ; done
        out+=${line:pos:j-pos+1} ; pos=$(( j + 1 )) ;;
      '"')
        out+='"' ; (( pos++ ))
        while (( pos < len )) && [[ ${line:pos:1} != '"' ]]; do
          if [[ ${line:pos:1} == \\ ]] && (( pos + 1 < len )); then
            case ${line:pos+1:1} in
              '$'|'`'|'"'|\\) delim+=${line:pos+1:1} ;;
              *)              delim+=${line:pos:2} ;;
            esac
            out+=${line:pos:2} ; (( pos+=2 ))
          else
            delim+=${line:pos:1} ; out+=${line:pos:1} ; (( pos++ ))
          fi
        done
        if (( pos < len )); then out+='"' ; (( pos++ )) ; fi ;;
      \\)
        delim+=${line:pos+1:1} ; out+=${line:pos:2} ; (( pos+=2 )) ;;
      *)
        delim+=$ch ; out+=$ch ; (( pos++ )) ;;
    esac
  done
  if (( seen )); then
    heredoc_delims+=("$delim") ; heredoc_strip+=("$strip") ; heredoc_quoted+=("$quoted_delim")
  fi
  last=word ; func_candidate=0
}

# --- Parentheses in command lists -------------------------------------------

# At a "(" inside a word, could be an extglob pattern. Bash only accepts that syntax if extglob was already on when the command was
# parsed, so the command gets a parse unit of its own (see "Parse units").
check_extglob_opener() {
  local lc
  (( in_word )) || return 1
  set_last_char
  case $lc in
    '@'|'!'|'*'|'+'|'?') need_parse_boundary ; return 0 ;;
  esac
  return 1
}

open_paren() {
  local j lc
  after_coproc=0

  if [[ $top == @(array|dbracket) ]]; then
    check_extglob_opener
    start_word "(" ; quoted=1 ; out+='(' ; (( pos++ )) ; push_frame pattern
    return
  fi

  if [[ $top == case ]] && [[ $case_state == pattern ]]; then
    if (( pattern_start && !in_word )); then
      # optional leading "(" of a case pattern
      emit_pending ; out+='(' ; (( pos++ )) ; pattern_start=0
    else
      check_extglob_opener
      start_word "(" ; quoted=1 ; out+='(' ; (( pos++ )) ; push_frame pattern
    fi
    return
  fi

  if (( in_word )); then
    if (( !quoted )) && [[ $word =~ $ASSIGNMENT_RE ]]; then
      quoted=1 ; out+='(' ; (( pos++ )) ; push_frame array
      return
    fi
    if check_extglob_opener; then   # extglob: @(a|b)
      quoted=1 ; out+='(' ; (( pos++ )) ; push_frame pattern
      return
    fi
    end_word
  fi

  # Function header: name() or function name()
  if (( func_candidate || after_function == 2 )); then
    j=$(( pos + 1 ))
    while (( j < len )) && [[ ${line:j:1} == [[:blank:]] ]]; do
      (( j++ ))
    done
    if [[ ${line:j:1} == ')' ]]; then
      emit_pending ; out+=${line:pos:j-pos+1} ; pos=$(( j + 1 ))
      cmd_pos=1 ; last=funchead ; after_function=0 ; words=0
      func_candidate=0
      return
    fi
  fi

  if (( cmd_pos || after_for == 1 )) && [[ ${line:pos+1:1} == '(' ]] && { (( after_for == 1 )) || closes_as_arithmetic $(( pos + 2 )); }; then
    emit_pending
    set_last_char ; [[ $lc == '(' ]] && out+=' '  # "( ((" must not become "((("
    out+='((' ; (( pos+=2 )) ; after_for=0
    push_frame arith_cmd
  elif (( cmd_pos )); then
    emit_pending
    set_last_char ; [[ $lc == '(' ]] && out+=' '  # "( (" must not become "((" (arithmetic)
    out+='(' ; (( pos++ )) ; push_frame subshell
  else
    start_word "(" ; quoted=1 ; out+='(' ; (( pos++ )) ; push_frame pattern
  fi
}

close_paren() {
  local closed
  end_word   # may be "esac", which changes what this ")" closes
  case $top in
    subshell|cmdsub|procsub)
      emit_pending_drop_semicolon ; out+=')' ; (( pos++ ))
      closed=$top ; pop_frame
      [[ $closed == subshell ]] && after_close ;;
    array)
      pending_sep="" ; emit_pending ; out+=')' ; (( pos++ )) ; pop_frame ;;
    case)
      emit_pending ; out+=')' ; (( pos++ ))
      if [[ $case_state == pattern ]]; then
        case_state=body ; last=keyword ; cmd_pos=1
        words=0 ; pattern_start=0
      else
        warn "line $line_no: unmatched ')' inside case body"
      fi ;;
    *)
      emit_pending ; out+=')' ; (( pos++ ))
      warn "line $line_no: unmatched ')'" ;;
  esac
}

# --- Operators in command lists ---------------------------------------------

read_semicolon() {   # ;  ;;  ;&  ;;&
  local op=';' was_bare_time
  end_word
  was_bare_time=$bare_time
  if [[ ${line:pos+1:1} == ';' ]]; then
    op=';;' ; [[ ${line:pos+2:1} == '&' ]] && op=';;&'
  elif [[ ${line:pos+1:1} == '&' ]]; then
    op=';&'
  fi
  # "a;" + newline + ";;" must not become "a;;;", and "a;" + ";&" must not
  # become "a;;&" (a different case terminator), so separate them with a space.
  # (This checks "last" rather than ${out: -1}: in a UTF-8 locale that reads
  # the whole output string, which made big inputs much slower.)
  [[ $op != ';' && $last == semi && -z $ws$pending_sep ]] && ws=' '
  emit_pending_drop_semicolon
  out+=$op ; (( pos += ${#op} ))
  [[ $op == ';' ]] && bare_time=$was_bare_time    # "time;" + newline: see bare_time
  last=end ; [[ $op == ';' ]] && last=semi
  words=0
  if [[ $top == case ]] && [[ $case_state == body && $op != ';' ]]; then
    case_state=pattern ; pattern_start=1 ; cmd_pos=0
  else
    cmd_pos=1 ; after_for=0
  fi
}

read_ampersand() {  # &&  &>  &>>  &
  end_word
  case ${line:pos+1:1} in
    '&')
      emit_pending ; out+='&&' ; (( pos+=2 ))
      last=continue ; cmd_pos=1 ; words=0 ; func_candidate=0 ;;
    '>')
      # A line starting with "&>" must not stick to what the previous line
      # ended with: "a" + "&>f b" must not become "a;&>f b" (";&" is a case
      # terminator) and "a &" + "&>f b" must not become "a &&>f b" (runs b
      # only if a succeeds, and a no longer in the background). Bash never
      # reads "&>" right after ";" or "&" on one line, so these can only come
      # from a joined newline.
      if [[ -z $ws ]] && [[ $pending_sep == ";" || $last == @(semi|bg) ]]; then
        ws=' '
      fi
      emit_pending ; out+='&>' ; (( pos+=2 ))
      if [[ ${line:pos:1} == '>' ]]; then
        out+='>' ; (( pos++ ))
      fi
      last=word ; func_candidate=0 ;;
    *)
      emit_pending_drop_semicolon ; out+='&' ; (( pos++ ))
      last=bg ; cmd_pos=1 ; words=0 ;;
  esac
}

read_pipe() { # |  ||  |&   (in a case pattern: alternation)
  local op='|'
  end_word ; emit_pending
  if [[ $top == case ]] && [[ $case_state == pattern ]]; then
    out+='|' ; (( pos++ )) ; pattern_start=0
    return
  fi
  case ${line:pos+1:1} in
    '|') op='||' ;;
    '&') op='|&' ;;
  esac
  out+=$op ; (( pos += ${#op} ))
  last=continue ; cmd_pos=1 ; words=0 ; func_candidate=0
}

read_angle() {  # <( >(  <<  <<<  < > >> >& >| <& <>
  local c=${line:pos:1} next=${line:pos+1:1} op
  after_compound=0     # "done > fi": the file name is not a reserved word
  # "a &" + newline + ">f b" must not become "a &>f b": that would redirect a
  # and turn b into its argument, so separate them with a space.
  [[ $c == '>' && $last == bg && $in_word == 0 && -z $ws$pending_sep ]] && ws=' '
  if [[ $next == '(' ]]; then
    start_word "$c" ; quoted=1
    out+="$c(" ; (( pos+=2 )) ; push_frame procsub
  elif [[ $top == array ]]; then
    word_char "$c"
  elif [[ $c == '<' && $next == '<' && ${line:pos+2:1} != '<' ]]; then
    end_word ; emit_pending ; read_heredoc_operator
  else
    end_word ; emit_pending
    op=$c
    if [[ $c == '<' && ${line:pos+1:2} == '<<' ]]; then op='<<<'
    elif [[ $c == '>' ]]; then
      case $next in '>'|'&'|'|') op+=$next ;; esac
    else
      case $next in '&'|'>') op+=$next ;; esac
    fi
    out+=$op ; (( pos += ${#op} ))
    last=word ; func_candidate=0
  fi
}

# --- One scanner per kind of frame ------------------------------------------
# Each reads from line at pos and advances pos by at least one.

scan_squote() {
  local rest=${line:pos} before
  before=${rest%%\'*}
  if [[ $before == "$rest" ]]; then
    out+=$rest ; pos=$len
    return
  fi
  out+="$before'" ; (( pos += ${#before} + 1 )) ; pop_frame
}

scan_dquote() {
  local rest=${line:pos} before
  before=${rest%%["$DQUOTE_SPECIAL"]*}
  if [[ -n $before ]]; then
    out+=$before ; (( pos += ${#before} ))
    return
  fi
  case ${line:pos:1} in
    \\)
      if (( pos == len - 1 )); then
        continued=1 ; pos=$len   # \ + newline vanishes
      else copy_escape ; fi ;;
    '"') out+='"' ; (( pos++ )) ; pop_frame ;;
    '$') open_dollar ;;
    '`') out+='`' ; (( pos++ )) ; push_frame backtick ;;
  esac
}

scan_ansi() {
  local rest=${line:pos} before
  before=${rest%%["$ANSI_SPECIAL"]*}
  if [[ -n $before ]]; then
    out+=$before ; (( pos += ${#before} ))
    return
  fi
  if [[ ${line:pos:1} == "'" ]]; then
    out+="'" ; (( pos++ )) ; pop_frame
  else copy_escape ; fi
}

scan_backtick() {
  local rest=${line:pos} before
  before=${rest%%["$BACKTICK_SPECIAL"]*}
  if [[ -n $before ]]; then
    out+=$before ; (( pos += ${#before} ))
    return
  fi
  if [[ ${line:pos:1} == '`' ]]; then
    out+='`' ; (( pos++ )) ; pop_frame
  else
    copy_escape
  fi
}

scan_param() {  # ${ ... }   (braces do not nest, same as bash)
  local c=${line:pos:1}
  case $c in
    \\)
      if (( pos == len - 1 )); then
        continued=1 ; pos=$len
      else
        copy_escape
      fi ;;
    '}') out+='}' ; (( pos++ )) ; pop_frame ;;
    "'") out+="'" ; (( pos++ )) ; push_frame squote ;;
    '"') out+='"' ; (( pos++ )) ; push_frame dquote ;;
    '$') open_dollar ;;
    '`') out+='`' ; (( pos++ )) ; push_frame backtick ;;
    *)   out+=$c ; (( pos++ )) ;;
  esac
}

scan_nested_parens() {  # arith, arith_cmd, paren, arith_bracket, bracket, pattern
  local c=${line:pos:1} lc
  case $c in
    \\)
      if (( pos == len - 1 )); then
        continued=1 ; pos=$len
      else
        copy_escape
      fi ;;
    '(')
      if [[ $top == pattern ]]; then
        # an extglob pattern inside ( ), as in [[ ( $x == @(a|b) ) ]]
        set_last_char
        case $lc in '@'|'!'|'*'|'+'|'?') need_parse_boundary ;; esac
        out+='(' ; (( pos++ )) ; push_frame pattern
      else
        out+='(' ; (( pos++ ))
        [[ $top == @(arith|arith_cmd|paren) ]] && push_frame paren
      fi ;;
    '[')
      out+='[' ; (( pos++ ))
      if [[ $top == @(arith_bracket|bracket) ]]; then
        push_frame bracket
      fi ;;
    ')')
      if [[ $top == @(paren|pattern) ]]; then
        out+=')' ; (( pos++ )) ; pop_frame
      elif [[ $top == @(arith|arith_cmd) ]] && [[ ${line:pos+1:1} == ')' ]]; then
        out+='))' ; (( pos+=2 ))
        if [[ $top == arith_cmd ]]; then
          pop_frame ; after_close
        else
          pop_frame
        fi
      else
        out+=')' ; (( pos++ ))
      fi ;;
    ']')
      out+=']' ; (( pos++ ))
      if [[ $top == @(arith_bracket|bracket) ]]; then
        pop_frame
      fi ;;
    "'")
      out+="'" ; (( pos++ ))
      if [[ $top == pattern ]]; then
        push_frame squote
      fi ;;
    '"') out+='"' ; (( pos++ )) ; push_frame dquote ;;
    '$') open_dollar ;;
    '`') out+='`' ; (( pos++ )) ; push_frame backtick ;;
    *)   out+=$c ; (( pos++ )) ;;
  esac
}

scan_command_list() { # top, subshell, group, cmdsub, procsub, case, array
  local c=${line:pos:1} rest run
  case $c in
    ' '|$'\t')
      end_word ; ws+=$c ; (( pos++ )) ;;
    '#')
      if (( in_word )); then
        word_char '#'
      else
        ws="" ; pos=$len # comment
      fi ;;
    \\)
      if (( pos == len - 1 )); then
        continued=1 ; pos=$len
      else
        start_word "$c" ; quoted=1 ; copy_escape
      fi ;;
    "'")
      start_word "$c" ; quoted=1 ; out+="'" ; (( pos++ )) ; push_frame squote ;;
    '"')
      start_word "$c" ; quoted=1 ; out+='"' ; (( pos++ )) ; push_frame dquote ;;
    '`')
      start_word "$c" ; quoted=1 ; out+='`' ; (( pos++ )) ; push_frame backtick ;;
    '$')
      start_word "$c" ; quoted=1 ; open_dollar ;;
    ';'|'&'|'|')
      if [[ $top == array ]]; then
        word_char "$c"
      elif [[ $c == ';' ]]; then
        read_semicolon
      elif [[ $c == '&' ]]; then
        read_ampersand
      else
        read_pipe
      fi ;;
    '<'|'>') read_angle ;;
    '(')     open_paren ;;
    ')')     close_paren ;;
    *)
      start_word "$c"
      rest=${line:pos} ; run=${rest%%["$LIST_SPECIAL"]*}
      out+=$run ; word+=$run ; (( pos += ${#run} )) ;;
  esac
}

scan_line() {
  local skipped=0
  len=${#line} ; pos=0

  # Leading whitespace only matters inside strings.
  if [[ $top == @(top|subshell|group|cmdsub|procsub|case|array|dbracket|arith|arith_cmd|paren|arith_bracket|bracket) ]]; then
    while (( pos < len )) && [[ ${line:pos:1} == [[:blank:]] ]]; do
      (( pos++ )) ; skipped=1
    done
    # After "foo \" + "  bar" the words stay separate; "foo\" + "bar" joins them.
    if (( continued && skipped )) && ! [[ $top == @(arith|arith_cmd|paren|arith_bracket|bracket) ]]; then
      end_word ; [[ -z $ws ]] && ws=" "
    fi
  fi
  continued=0

  while (( pos < len )); do
    case $top in
      squote)   scan_squote ;;
      dquote)   scan_dquote ;;
      ansi)     scan_ansi ;;
      backtick) scan_backtick ;;
      param)    scan_param ;;
      arith|arith_cmd|paren|arith_bracket|bracket|pattern) scan_nested_parens ;;
      *)        scan_command_list ;;
    esac
  done
}

# --- What a newline becomes -------------------------------------------------

end_of_line() {
  if [[ $top == @(squote|ansi|dquote|param|backtick|pattern) ]]; then
    out+=$'\n' ; return
  fi
  if [[ $top == @(arith|arith_cmd|paren|arith_bracket|bracket) ]]; then
    out+=' ' ; return
  fi

  end_word ; ws="" ; func_candidate=0

  if [[ $top == dbracket ]]; then
    pending_sep=" "
    return
  fi

  # Heredoc bodies start on the next line; the newline must stay real.
  if (( ${#heredoc_delims[@]} > 0 && !heredoc_active )); then
    out+=$'\n' ; heredoc_active=1 ; pending_sep=""
    [[ $last == word ]] && last=end
    cmd_pos=1 ; words=0
    # A complete command at the top level (of the script or of a $( )): the next one starts a new parse unit, already after
    # a real newline (the end of the heredoc body).
    if (( kw_depth == 0 )) && [[ $last == @(end|semi|bg) ]]; then
      if (( sp == 0 )); then
        top_boundary=2
      elif [[ $top == @(cmdsub|procsub) ]]; then
        cs_boundary=2
      fi
    fi
    return
  fi

  if [[ $top == array ]]; then
    [[ $last == word ]] && pending_sep=" "
  elif [[ $top == case ]] && [[ $case_state == subject ]]; then
    pending_sep=" "
  elif [[ $top == case ]] && [[ $case_state == pattern ]]; then
    [[ $last == keyword ]] && pending_sep=" "
  elif (( after_for == 2 )) && [[ $last == word ]]; then
    # "for NAME" + newline + "in ..." / "do": the loop is not finished, and "for i;in" is invalid. "for i in" and "for i do" are both fine.
    pending_sep=" " ; cmd_pos=0
  else
    case $last in
      word) pending_sep=";" ; last=end ;;
      keyword|continue|funchead) pending_sep=" " ;;
    esac
    if (( parse_affecting || bare_time )); then
      pending_sep=$'\n'
      [[ $last == word ]] && last=end
    fi
    cmd_pos=1 ; words=0 ; after_for=0 ; after_coproc=0
    # A newline after a complete command at the top level (of the script or of a $( )): bash stops parsing here and runs what it has, so the next command starts a new parse unit.
    if (( kw_depth == 0 )) && [[ $last == @(end|semi|bg) ]]; then
      if (( sp == 0 )); then
        (( top_boundary == 2 )) || top_boundary=1
      elif [[ $top == @(cmdsub|procsub) ]]; then
        (( cs_boundary == 2 )) || cs_boundary=1
      fi
    fi
  fi
}

# Heredoc body line. Copy verbatim.
# In an unquoted heredoc bash first removes \+newline, so the line that is compared is the joined one: "foo\" + "EOF" is "fooEOF" (not the end), and
# "E\" + "OF" is "EOF" (the end). <<- strips tabs only where a joined line starts. An even number of trailing backslashes is not a continuation.
heredoc_line() {
  local check=$line trailing
  out+="$line"$'\n'
  if (( !heredoc_cont )) && [[ ${heredoc_strip[heredoc_index]} == 1 ]]; then
    check=${check#"${check%%[!$'\t']*}"}    # <<- ignores leading tabs
  fi
  check=$heredoc_logical$check
  if [[ ${heredoc_quoted[heredoc_index]} == 0 ]]; then
    trailing=${line##*[!\\]}  # the run of backslashes at the end
    if (( ${#trailing} % 2 )); then
      heredoc_logical=${check%\\} ; heredoc_cont=1
      return
    fi
  fi
  heredoc_logical="" ; heredoc_cont=0
  if [[ $check == "${heredoc_delims[heredoc_index]}" ]]; then
    (( heredoc_index++ ))
    if (( heredoc_index >= ${#heredoc_delims[@]} )); then
      heredoc_active=0 ; heredoc_index=0
      heredoc_delims=() ; heredoc_strip=() ; heredoc_quoted=()
    fi
  fi
}

# ####### Main loop ##############################################################

# "for line in" for bash 3.2 performance
idx=-1
for line in "${lines[@]}"; do
  (( ++idx < first_line )) && continue
  line_no=$(( idx + 1 ))
  [[ "$debug" == "1" ]] && echo "LINE $line_no: stack=$(stack_string) heredoc=$heredoc_active" >&2

  if (( heredoc_active )); then
    heredoc_line ; flush_out
    continue
  fi
  scan_line
  if (( !continued )); then
    end_of_line ; parse_affecting=0 ; bare_time=0
  fi
  flush_out
done

# Report anything still open.
unclosed=0
if (( heredoc_active )); then
  unclosed=1
  warn "input ended inside a heredoc (delimiter '${heredoc_delims[heredoc_index]}')"
fi
(( sp > 0 )) && unclosed=1
for (( k=sp; k>0; k-- )); do
  if (( k == sp )); then
    warn "input ended inside $(describe_frame "${stack[k]}") opened on line ${stack_line[k]}"
  else
    warn "...inside $(describe_frame "${stack[k]}") opened on line ${stack_line[k]}"
  fi
done
[[ $pending_sep == ";" ]] && out+=";"
body=$done_out$held_sep$held$out

# Refuse to write output for input that ends inside an open construct.
# The minifier does not repair input.
if (( unclosed )); then
  echo "The input ends inside an unclosed construct (see warnings above); nothing was written." >&2
  echo "Error code: 7. Exiting" >&2; exit 7
fi

# Assemble output
if [[ -n $shebang ]]; then
  fullfile="$(printf '%s\n' "$shebang"; printf '%s' "$body")"
else
  fullfile="$(printf '%s' "$body")"
fi

# Verify: if the input parses with bash -n, the output must parse too.
if (( verify )); then
  if ! printf '%s\n' "${lines[@]}" | "$BASH" -O extglob -n 2>/dev/null; then
    # On bash 3.2 this is also the case for valid scripts that use newer syntax such as ;& ;;& |& coproc or case inside $( ).
    warn "The input does not parse with bash $BASH_VERSION (syntax errors, or syntax from a newer bash); output not verified"
  elif ! verify_errors=$(printf '%s\n' "$fullfile" | exec -a output "$BASH" -O extglob -n 2>&1); then
    echo "The minified output is not valid bash, although the input is. This is a minifier bug:" >&2
    echo "$verify_errors" >&2
    echo "Nothing was written. Use --no-verify to write it anyway." >&2
    echo "Error code: 8. Exiting" >&2; exit 8
  fi
fi

if [[ "$output" == "stdout" ]]; then
  printf '%s\n' "$fullfile" || exitw 9 "Could not write the output to stdout."
elif [[ "$output" == "file" ]]; then
  printf '%s\n' "$fullfile" > "$output_file" || exitw 9 "Could not write the output file '$output_file'."
  chmod "$permission" "$output_file" || exitw 9 "The output was written to '$output_file', but its permissions could not be set to '$permission'."
else
  exitw 6
fi

exit 0
