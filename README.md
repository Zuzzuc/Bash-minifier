# Bash-minifier

A bash script used to minify other bash scripts.

This script will attempt convert any bash script to a one liner (or two lines if counting the shebang) using a state aware parser. This is not always possible for a valid bash syntax, for example with heredocs, which will be left in place.

# Usage
Example usage:
<br>
<br>
`/Minify.sh -f="$HOME/Desktop/test.sh"`
This will minify a script named "test.sh" on the desktop and output its content to stdout.
<br>
<br>`/Minify.sh -f="$HOME/Desktop/test.sh" -o="$HOME/Desktop/output.sh"`
This will do the same, but will write the output to a file named "output.sh", and give it execution permissions(due to default settings not overrun), on the users desktop. 
<br>
<br>`/Minify.sh -F -f="$HOME/Desktop/test.sh" -o="$HOME/Desktop/output.sh" -p=u-r`
This will minify and write the script to desktop, and remove read access for the current user from it. 
<br>

## Supported options
### File
#### -f or --file
#### Requires a parameter
#### This option is REQUIRED for this script to work.
<br>This option chooses what file to read from.<br><br>
Example: `./Minify.sh -f=test.sh`
<br><br><br>
### Force
#### -F or --force
#### Should not be supplied with a parameter.
#### Disabled by default
<br>If this option is enabled the script will skip any security checks and will therefore not prompt the user at any time.<br><br>
Example: `./Minify.sh -F -f=test.sh`
<br><br><br>

### Output
#### -o or --output
#### Requires a parameter
#### Defaults to STDOUT
<br>This option specifies where to send the output.<br><br>
STDOUT will simply send the output to stdout.<br>
<br>File will write the output to a file. To activate this option, simply specify a file path. If a file already exists in the filepath, the script will prompt the user and ask if the file should be overwritten.<br><br>
Examples: `./Minify.sh -F -f=test.sh -o=STDOUT`<br>`./Minify.sh -F -f=test.sh -o="$HOME/Desktop/output.sh"` 
<br><br><br>

### Permission
#### -p or --permission
#### Requires a parameter
#### Defaults to u+x
<br>This option will, in case of the output being a file, set the file permission to the content of the parameter<br><br>
Example: `./Minify.sh -F -f=test.sh -o=$HOME/Desktop/output.sh -p=u-r`

## Exit codes

0: Everything went well<br>
1: Unknown error<br>
2: User declined to continue when warned<br>
3: File does not exist<br>
4: Unknown argument supplied to script<br> 
5: This script will not minify itself<br>
6: Unknown output mode encountered<br>
