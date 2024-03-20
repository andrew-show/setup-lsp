# setup-lsp

Tools use to generate compile_commands.json for C/C++ project

## Make and install

make

make install

## How to use

setup-lsp.sh <Build command>

## Use case
Generate compile_commands.json for linux kernel source

# cd linux/src

# make menuconfig

# setup-lsp.sh make -j8

