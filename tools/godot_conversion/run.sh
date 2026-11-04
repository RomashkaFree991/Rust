#!/bin/bash
# usage: run.sh script.py args...
s=$1; shift
python3 -c "import sys; sys.argv=['blender','--',*sys.argv[1:]]; exec(open('$s').read())" "$@"
