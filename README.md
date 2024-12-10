# setup-lsp

Tools use to generate compile_commands.json for C/C++ project

## Make and install

make

make install

## How to use

setup-lsp.sh --help

## Use case
======================================================
Generate compile_commands.json for linux kernel source
======================================================
cd linux/src

make menuconfig

setup-lsp.sh make -j8

======================================================
Generate compile_commands.json for DPDK
======================================================
cd dpdk-21.11

meson setup build 
setup-lsp.sh -C build ninja
