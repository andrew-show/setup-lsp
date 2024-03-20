#!/bin/bash

# $1: path
# $2: working directory
function abs_path()
{
    if [[ "$1" =~ / ]]; then
        realpath -m -s $1
    else
        realpath -m -s $2/$1
    fi
}

function make_database()
{
    while read line; do
        set -- $line

        pwd=$1
        shift

        if [[ "$1" =~ (^|/)(gcc|g\+\+|clang|clang\+\+)$ ]]; then
            args=$1
            shift

            objs=
            srcs=
            while [ $# -ne 0 ]; do
                if [[ "$1" =~ ^-I ]]; then
                    if [[ "$1" == "-I" ]]; then
                        shift
                        path="$1"
                    else
                        path=${1#-I}
                    fi

                    args="$args -I $(abs_path $path $pwd)"
		        elif [[ "$1" == "-include" ]]; then
		            shift
		            args="$args -include $(abs_path $1 $pwd)"
                elif [[ "$1" == "-o" ]]; then
                    shift 
                    args="$args -o $1"
                    objs="$objs $1"
                elif [[ "$1" =~ \.(c|cc|cxx|cpp)$ ]]; then 
                    srcs="$srcs $1"
                else
                    args="$args $1"
                fi

                shift
            done

            if [ "X$objs" != "X" ]; then
                for i in $srcs; do
                    file=$(abs_path $i $pwd)
                    command=$(echo $args $file | sed 's/\"/\\"/g')
                    cat >> $PWD/compile_commands.json <<EOF
{
    "directory": "$PWD",
    "file": "$file",
    "command": "$command"
},
EOF
                done
            fi
        fi
    done
}

if [ "X$1" == "X" ]; then
    echo "Usage: setup-lsp.sh <Command to build software>" > /dev/stderr
    exit 1
fi

echo '[' > $PWD/compile_commands.json

# setup unix domain socket path for args-probe
export ARGS_PROBE=/tmp/setup-lsp-$$

# start args-probe to probe command line arguments
args-probe $ARGS_PROBE > >(make_database) &

ARGS_PROBE_PID=$!

# setup preload shared library to probe and advise command line arguments.
export LD_PRELOAD=libargs-advise.so

$@

# wait 1 seconds to make sure every thing is done
sleep 1

# kill args-probe process
kill -2 $ARGS_PROBE_PID

sed -i '$ s/,$//' $PWD/compile_commands.json
echo ']' >> $PWD/compile_commands.json
