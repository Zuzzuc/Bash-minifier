# Bash-minifier


A script used to minify other scripts. 
<br><br>
Does currently only support full line comments. This means that this will work 
```
#!/bin/bash
# The next line will output the current date
date
```
whilst this wont work 
```
#!/bin/bash
date # This will output the current date
```

# Usage


## Exit codes

0: Everything went well
1: Unknown error
2: User declined to continue when warned about script content
3: File does not exist
4: Unknown argument supplied to script
5: This script will not minify itself
6: Unknown output mode encountered
