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
##### This argument is REQUIRED for this script to work.
<br>This option chooses what file to read from

## Exit codes

0: Everything went well<br>
1: Unknown error<br>
2: User declined to continue when warned about script content<br>
3: File does not exist<br>
4: Unknown argument supplied to script<br>
5: This script will not minify itself<br>
6: Unknown output mode encountered<br>
