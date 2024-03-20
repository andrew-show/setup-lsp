#!/bin/bash

export ARGS_PROBE=/tmp/args-probe-$$
args-probe $ARGS_PROBE > $1 &

export ARGS_PROBE_PID=$!

LD_PRELOAD=libargs-advise.so
export LD_PRELOAD

$@

sleep 1
kill -2 $ARGS_PROBE_PID
