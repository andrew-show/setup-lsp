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
    append=$2
    prefix=$3
    base=$(mktemp -d)

    if [ -f $database -a $append == "yes" ]; then
        sed -i ':a /^.*\][\n \t]*/ { $ s/^\(.*\)\]/\1/; N; ba }' $database
        sed -i ':a /^.*}[\n \t]*/ { $ s/^\(.*\)}[\n \t]*/\1},/; N; ba }' $database
    else
        echo '[' > $database
    fi

    local line
    while read line; do
        set -- $line

        pwd=$1
        shift

        executable=$1
        shift

        if [[ "$1" =~ (^|/)${prefix}(gcc|g\+\+|cc|c\+\+|clang|clang\+\+)$ ]]; then
            shift

            args=$@
            preprocessor=
            srcs=
            targets=
            while [ $# -ne 0 ]; do
                case "$1" in
                    -I|-include|-iquote|-isystem|-idirafter|-iprefix|-iwithprefix|-iwithprefixbefore|-isysroot|-imultilib|-D|-U|-imacros|-Xpreprocessor)
                        preprocessor="$preprocessor $1 $2"
                        shift
                        ;;
                    -I*|-include*|-iquote*|-isystem*|-idirafter*|-iprefix*|-iwithprefix*|-iwithprefixbefore*|-isysroot*|-imultilib*|--sysroot=*|-nostdinc|-nostdinc++|-D*|-U*|-undef|-Wp,*|-imacros*|-no-integrated-cpp|-pthread|-std=*)
                        preprocessor="$preprocessor $1"
                        ;;
                    -main-file-name)
                        shift
                        ;;
                    -o)
                        shift 
                        targets="$targets $1"
                        ;;
                    *.c|*.cc|*.cxx|*.cpp)
                        srcs="$srcs $1"
                        ;;
                    *)
                        ;;
                esac

                shift
            done

            if [ "X$targets" != "X" ]; then
                for src in $srcs; do
                    if [ -f $src ]; then
                        command=$(echo $executable $args | sed 's/\"/\\"/g')
                        cat >> $database <<EOF
  {
    "directory": "$pwd",
    "file": "$src",
    "command": "$command"
  },
EOF
                        cd $pwd

                        $executable $preprocessor -MM -E $src | sed -e 's/^[^:]*: [^ ]*//' -e 's/ \\$//' | while read heads; do
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
                    fi
                done
            fi
        fi
    done

    rm -rf $base

    sed -i ':a /^.*},[\n \t]*/ { $ s/^\(.*\)},[\n \t]*/\1}/; N; ba }' $database
    echo ']' >> $database
}

function usage()
{
    echo "Usage: setup-lsp.sh [Optiions] <Command to build software>" > /dev/stderr
    echo "  -C <dir>     Specify the working directory for build command"
    echo "  -o <path>    Path to compile database, the default is ./compile_commands.json"
    echo "  -a           Append new content to existing file"
    echo "  -p           Specify the cross compile prefix for compiler and linker"
    echo "  -h|--help    Display the message"
    exit 1
}

if [ "X$1" == "X" ]; then
    usage
fi

DIR=$PWD
BUILD_DIR=$PWD
OUTPUT=$DIR/compile_commands.json
APPEND=no
PREFIX=

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
        -a)
            APPEND=yes
            ;;
        -p)
            shift
            PREFIX=$1
            ;;
        -h|--help)
            usage
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
$PATH_ARGS_PROBE $ARGS_PROBE > >(make_database $OUTPUT $APPEND $PREFIX) &

ARGS_PROBE_PID=$!

sleep 1

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
