TOPDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

CC=gcc
CXX=g++

ifeq ($(BUILD_TARGET),)

###############################################################################
# define variables for multiple targets
###############################################################################

BUILD_TARGET_LIST=$(shell $(CC) -dumpmachine)

else

###############################################################################
# define variables for build single specific target
###############################################################################

PKGS :=
STATIC_PKGS :=
OPTIONAL_PKGS :=

CPPFLAGS += -D_GNU_SOURCE

CXXFLAGS += -std=c++11
CFLAGS += -std=gnu99

LDFLAGS +=

endif
