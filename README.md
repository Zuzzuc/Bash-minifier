# Bash-minifier


A script used to minify other scripts. 
<br><br>
Does currently only support full line comments. This means that this will work 
```
#!/bin/bash
# The next line will output the current date
date
```
whilst this won't work 
```
#!/bin/bash
date # This will output the current date
```

# Usage

## Supported options
<br>
### File
#### -f or --file
#### Requires a parameter
#### This option is REQUIRED for this script to work.
<br>This option chooses what file to read from.<br><br>
Example: `/Minify.sh -f=test.sh`
<br><br><br>
### Force
#### -F or -force
#### Should not be supplied with a parameter
##### Disabled by default
<br>If this option is enabled the script will skip any security checks and will therefore not promt the user at any time.<br><br>
Example: `/Minify.sh -F -f=test.sh`
<br><br><br>
### Mode
#### -m or --mode
#### Requires a parameter
##### Defaults to RAM
<br>This option will specify what mode to use. Right now there is only one mode avaliable, RAM, but there will be multiple added in the future<br><br>
RAM mode will read the whole script into RAM before making changes, and writing them to stdout or file first when all changes are complete.
<br><br>
Example: `/Minify.sh -F -f=test.sh -m=RAM`
<br><br><br>

### Output
#### -o or --output
#### Requires a parameter
#### Defaults to STDOUT
<br>This option specifies where to send the output.<br><br>
STDOUT will simply send the output to stdout.<br>
By specificating a file path the script will write the output to that file.<br><br>
Examples: `/Minify.sh -F -f=test.sh -m=RAM -o=STDOUT` `/Minify.sh -F -f=test.sh -m=RAM -o="$HOME/Desktop/output.sh"` 

## Exit codes

0: Everything went well<br>
1: Unknown error<br>
2: User declined to continue when warned about script content<br>
3: File does not exist<br>
4: Unknown argument supplied to script<br>
5: This script will not minify itself<br>
6: Unknown output mode encountered<br>
