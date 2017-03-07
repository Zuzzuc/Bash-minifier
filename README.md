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

## Usage
