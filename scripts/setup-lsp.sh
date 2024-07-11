#!/bin/bash

# $1: path
# $2: working directory
function abs_path()
{
    if [[ "$1" =~ / ]]; then
        realpath -L -m -s $1
    else
        realpath -L -m -s $2/$1
    fi
}

function make_database()
{
    database=$1
    base=$(mktemp -d)

    echo '[' > $database

    local line
    while read line; do
        set -- $line

        pwd=$1
        shift

        executable=$1
        shift

        if [[ "$1" =~ (^|/)(gcc|g\+\+|cc|c\+\+|clang|clang\+\+)$ ]]; then
            shift

            args=
            objs=
            srcs=
            while [ $# -ne 0 ]; do
                case "$1" in
                    -I)
                        shift
                        args="$args -I$1"
                        ;;
                    -I*)
                        args="$args $1"
                        ;;
                    -include)
		                shift
		                args="$args -include $1"
                        ;;
                    -o)
                        shift 
                        objs="$objs $1"
                        ;;
                    *.c|*.cc|*.cxx|*.cpp)
                        srcs="$srcs $1"
                        ;;
                    -MF)
                        shift
                        ;;
                    -Wp,-MD,*)
                        shift
                        ;;
                    -Wp,-MMD,*)
                        shift
                        ;;
                    -c|-M|-MM|-MD)
                        ;;
                    *)
                        args="$args $1"
                        ;;
                esac

                shift
            done

            if [ "X$objs" != "X" ]; then
                for src in $srcs; do
                    obj=$(echo $src | sed 's%\.[^\.]*$%%').o
                    command=$(echo $executable $args -o $obj -c $src | sed 's/\"/\\"/g')
                    cat >> $database <<EOF
  {
    "directory": "$pwd",
    "file": "$src",
    "command": "$command"
  },
EOF
                    cd $pwd

                    $executable $args -MM $src | sed -e 's/^[^:]*: [^ ]*//' -e 's/ \\$//' | while read heads; do
                        for head in $heads; do
                            path=$base/$(realpath -L -m -s $head)
                            if [ ! -f $path ]; then
                                mkdir -p $(dirname $path)
                                touch $path
                                cat >> $database <<EOF
  {
    "directory": "$pwd",
    "file": "$head",
    "command": "$command"
  },
EOF
                            fi
                        done
                    done
                done
            fi
        fi
    done

    rm -rf $base

    sed -i '$ s/,$//' $database
    echo ']' >> $database
}

if [ "X$1" == "X" ]; then
    echo "Usage: setup-lsp.sh [Optiions] <Command to build software>" > /dev/stderr
    echo "  -C <dir>     Specify the working directory for build command"
    exit 1
fi

DIR=$PWD
BUILD_DIR=$PWD
OUTPUT=$DIR/compile_commands.json

while [ -n $1 ]; do
    case "$1" in
        -C)
            shift
            BUILD_DIR=$1
            ;;
        -o)
            shift
            OUTPUT=$(realpath -m -s $1)
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ ! -d "$BUILD_DIR" ]; then
    echo "Build directory $BUILD_DIR doesn't exist" > /dev/stderr
    exit 1
fi

PATH_ARGS_PROBE=$(which args-probe)
if [ "X$PATH_ARGS_PROBE" == "X" ]; then
    echo "Can't find args-probe in PATH" > /dev/stderr
    exit 1
fi

PATH_LIBARGS_ADVISE=$(dirname $PATH_ARGS_PROBE)/../lib/libargs-advise.so
if [ ! -f "$PATH_LIBARGS_ADVISE" ]; then
    echo "Can't find libargs-advise.so in $(dirname $PATH_LIBARGS_ADVISE)" > /dev/stderr
    exit 1
fi

# setup unix domain socket path for args-probe
export ARGS_PROBE=/tmp/setup-lsp-$$

# start args-probe to probe command line arguments
$PATH_ARGS_PROBE $ARGS_PROBE > >(make_database $OUTPUT) &

ARGS_PROBE_PID=$!

# setup preload shared library to probe and advise command line arguments.
export LD_PRELOAD=$PATH_LIBARGS_ADVISE

# Execute build command
cd $BUILD_DIR
$@

cd $DIR

# wait 3 seconds to make sure every thing is done
sleep 1

# kill args-probe process
kill -2 $ARGS_PROBE_PID

while true; do
    tail -1 $OUTPUT | grep '\]' > /dev/null
    if [ $? -eq 0 ]; then
        break
    fi
done
