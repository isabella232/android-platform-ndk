# Copyright (C) 2009-2010, 2014 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Initialization of the NDK build system. This file is included by
# several build scripts.
#

# Disable GNU Make implicit rules

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:


# Define NDK_LOG=1 in your environment to display log traces when
# using the build scripts. See also the definition of ndk_log below.
#
NDK_LOG := $(strip $(NDK_LOG))
ifeq ($(NDK_LOG),true)
    override NDK_LOG := 1
endif

# Define NDK_HOST_32BIT=1 in your environment to always use toolchain in 32-bit
# even if 64-bit is present.  Note that toolchains in 64-bit still produce
# 32-bit binaries for Android
#
NDK_HOST_32BIT := $(strip $(NDK_HOST_32BIT))
ifeq ($(NDK_HOST_32BIT),true)
    override NDK_HOST_32BIT := 1
endif

# Check that we have at least GNU Make 3.81
# We do this by detecting whether 'lastword' is supported
#
MAKE_TEST := $(lastword a b c d e f)
ifneq ($(MAKE_TEST),f)
    $(error Android NDK: GNU Make version $(MAKE_VERSION) is too low (should be >= 3.81))
endif
ifeq ($(NDK_LOG),1)
    $(info Android NDK: GNU Make version $(MAKE_VERSION) detected)
endif

# NDK_ROOT *must* be defined and point to the root of the NDK installation
NDK_ROOT := $(strip $(NDK_ROOT))
ifndef NDK_ROOT
    $(error ERROR while including init.mk: NDK_ROOT must be defined !)
endif
ifneq ($(words $(NDK_ROOT)),1)
    $(info,The Android NDK installation path contains spaces: '$(NDK_ROOT)')
    $(error,Please fix the problem by reinstalling to a different location.)
endif

# ====================================================================
#
# Define a few useful variables and functions.
# More stuff will follow in definitions.mk.
#
# ====================================================================

# Used to output warnings and error from the library, it's possible to
# disable any warnings or errors by overriding these definitions
# manually or by setting NDK_NO_WARNINGS or NDK_NO_ERRORS

__ndk_name    := Android NDK
__ndk_info     = $(info $(__ndk_name): $1 $2 $3 $4 $5)
__ndk_warning  = $(warning $(__ndk_name): $1 $2 $3 $4 $5)
__ndk_error    = $(error $(__ndk_name): $1 $2 $3 $4 $5)

ifdef NDK_NO_WARNINGS
__ndk_warning :=
endif
ifdef NDK_NO_ERRORS
__ndk_error :=
endif

# -----------------------------------------------------------------------------
# Function : ndk_log
# Arguments: 1: text to print when NDK_LOG is defined to 1
# Returns  : None
# Usage    : $(call ndk_log,<some text>)
# -----------------------------------------------------------------------------
ifeq ($(NDK_LOG),1)
ndk_log = $(info $(__ndk_name): $1)
else
ndk_log :=
endif

# -----------------------------------------------------------------------------
# Function : host-prebuilt-tag
# Arguments: 1: parent path of "prebuilt"
# Returns  : path $1/prebuilt/(HOST_TAG64) exists and NDK_HOST_32BIT isn't defined to 1,
#            or $1/prebuilt/(HOST_TAG)
# Usage    : $(call host-prebuilt-tag, <path>)
# Rationale: This function is used to proble available 64-bit toolchain or
#            return 32-bit one as default.  Note that HOST_TAG64==HOST_TAG for
#            32-bit system (or 32-bit userland in 64-bit system)
# -----------------------------------------------------------------------------
ifeq ($(NDK_HOST_32BIT),1)
host-prebuilt-tag = $1/prebuilt/$(HOST_TAG)
else
host-prebuilt-tag = \
   $(if $(strip $(wildcard $1/prebuilt/$(HOST_TAG64))),$1/prebuilt/$(HOST_TAG64),$1/prebuilt/$(HOST_TAG))
endif

# ====================================================================
#
# Host system auto-detection.
#
# ====================================================================

#
# Determine host system and architecture from the environment
#
HOST_OS := $(strip $(HOST_OS))
ifndef HOST_OS
    # On all modern variants of Windows (including Cygwin and Wine)
    # the OS environment variable is defined to 'Windows_NT'
    #
    # The value of PROCESSOR_ARCHITECTURE will be x86 or AMD64
    #
    ifeq ($(OS),Windows_NT)
        HOST_OS := windows
    else
        # For other systems, use the `uname` output
        UNAME := $(shell uname -s)
        ifneq (,$(findstring Linux,$(UNAME)))
            HOST_OS := linux
        endif
        ifneq (,$(findstring Darwin,$(UNAME)))
            HOST_OS := darwin
        endif
        # We should not be there, but just in case !
        ifneq (,$(findstring CYGWIN,$(UNAME)))
            HOST_OS := windows
        endif
        ifeq ($(HOST_OS),)
            $(call __ndk_info,Unable to determine HOST_OS from uname -s: $(UNAME))
            $(call __ndk_info,Please define HOST_OS in your environment.)
            $(call __ndk_error,Aborting.)
        endif
    endif
    $(call ndk_log,Host OS was auto-detected: $(HOST_OS))
else
    $(call ndk_log,Host OS from environment: $(HOST_OS))
endif

# For all systems, we will have HOST_OS_BASE defined as
# $(HOST_OS), except on Cygwin where we will have:
#
#  HOST_OS      == cygwin
#  HOST_OS_BASE == windows
#
# Trying to detect that we're running from Cygwin is tricky
# because we can't use $(OSTYPE): It's a Bash shell variable
# that is not exported to sub-processes, and isn't defined by
# other shells (for those with really weird setups).
#
# Instead, we assume that a program named /bin/uname.exe
# that can be invoked and returns a valid value corresponds
# to a Cygwin installation.
#
HOST_OS_BASE := $(HOST_OS)

ifeq ($(HOST_OS),windows)
    ifneq (,$(strip $(wildcard /bin/uname.exe)))
        $(call ndk_log,Found /bin/uname.exe on Windows host, checking for Cygwin)
        # NOTE: The 2>NUL here is for the case where we're running inside the
        #       native Windows shell. On cygwin, this will create an empty NUL file
        #       that we're going to remove later (see below).
        UNAME := $(shell /bin/uname.exe -s 2>NUL)
        $(call ndk_log,uname -s returned: $(UNAME))
        ifneq (,$(filter CYGWIN%,$(UNAME)))
            $(call ndk_log,Cygwin detected: $(shell uname -a))
            HOST_OS := cygwin
            DUMMY := $(shell rm -f NUL) # Cleaning up
        else
            ifneq (,$(filter MINGW32%,$(UNAME)))
                $(call ndk_log,MSys detected: $(shell uname -a))
                HOST_OS := cygwin
            else
                $(call ndk_log,Cygwin *not* detected!)
            endif
        endif
    endif
endif

ifneq ($(HOST_OS),$(HOST_OS_BASE))
    $(call ndk_log, Host operating system detected: $(HOST_OS), base OS: $(HOST_OS_BASE))
else
    $(call ndk_log, Host operating system detected: $(HOST_OS))
endif

# Always use /usr/bin/file on Darwin to avoid relying on broken Ports
# version. See http://b.android.com/53769 .
HOST_FILE_PROGRAM := file
ifeq ($(HOST_OS),darwin)
HOST_FILE_PROGRAM := /usr/bin/file
endif

HOST_ARCH := $(strip $(HOST_ARCH))
HOST_ARCH64 :=
ifndef HOST_ARCH
    ifeq ($(HOST_OS_BASE),windows)
        HOST_ARCH := $(PROCESSOR_ARCHITECTURE)
        ifeq ($(HOST_ARCH),AMD64)
            HOST_ARCH := x86
        endif
        # Windows is 64-bit if either ProgramW6432 or ProgramFiles(x86) is set
        ifneq ("/",$(shell echo "%ProgramW6432%/%ProgramFiles(x86)%"))
            HOST_ARCH64 := x86_64
        endif
    else # HOST_OS_BASE != windows
        UNAME := $(shell uname -m)
        ifneq (,$(findstring 86,$(UNAME)))
            HOST_ARCH := x86
            ifneq (,$(shell $(HOST_FILE_PROGRAM) -L $(SHELL) | grep 'x86[_-]64'))
                HOST_ARCH64 := x86_64
            endif
        endif
        # We should probably should not care at all
        ifneq (,$(findstring Power,$(UNAME)))
            HOST_ARCH := ppc
        endif
        ifeq ($(HOST_ARCH),)
            $(call __ndk_info,Unsupported host architecture: $(UNAME))
            $(call __ndk_error,Aborting)
        endif
    endif # HOST_OS_BASE != windows
    $(call ndk_log,Host CPU was auto-detected: $(HOST_ARCH))
else
    $(call ndk_log,Host CPU from environment: $(HOST_ARCH))
endif

ifeq (,$(HOST_ARCH64))
    HOST_ARCH64 := $(HOST_ARCH)
endif

HOST_TAG := $(HOST_OS_BASE)-$(HOST_ARCH)
HOST_TAG64 := $(HOST_OS_BASE)-$(HOST_ARCH64)

# The directory separator used on this host
HOST_DIRSEP := :
ifeq ($(HOST_OS),windows)
  HOST_DIRSEP := ;
endif

# The host executable extension
HOST_EXEEXT :=
ifeq ($(HOST_OS),windows)
  HOST_EXEEXT := .exe
endif

# If we are on Windows, we need to check that we are not running
# Cygwin 1.5, which is deprecated and won't run our toolchain
# binaries properly.
#
ifeq ($(HOST_TAG),windows-x86)
    ifeq ($(HOST_OS),cygwin)
        # On cygwin, 'uname -r' returns something like 1.5.23(0.225/5/3)
        # We recognize 1.5. as the prefix to look for then.
        CYGWIN_VERSION := $(shell uname -r)
        ifneq ($(filter XX1.5.%,XX$(CYGWIN_VERSION)),)
            $(call __ndk_info,You seem to be running Cygwin 1.5, which is not supported.)
            $(call __ndk_info,Please upgrade to Cygwin 1.7 or higher.)
            $(call __ndk_error,Aborting.)
        endif
    endif
    # special-case the host-tag
    HOST_TAG := windows
endif

$(call ndk_log,HOST_TAG set to $(HOST_TAG))

# Check for NDK-specific versions of our host tools
HOST_PREBUILT_ROOT := $(call host-prebuilt-tag, $(NDK_ROOT))
HOST_PREBUILT := $(strip $(wildcard $(HOST_PREBUILT_ROOT)/bin))
HOST_AWK := $(strip $(NDK_HOST_AWK))
HOST_MAKE := $(strip $(NDK_HOST_MAKE))
HOST_PYTHON := $(strip $(NDK_HOST_PYTHON))
ifdef HOST_PREBUILT
    $(call ndk_log,Host tools prebuilt directory: $(HOST_PREBUILT))
    # The windows prebuilt binaries are for ndk-build.cmd
    # On cygwin, we must use the Cygwin version of these tools instead.
    ifneq ($(HOST_OS),cygwin)
        ifndef HOST_AWK
            HOST_AWK := $(wildcard $(HOST_PREBUILT)/awk$(HOST_EXEEXT))
        endif
        ifndef HOST_MAKE
            HOST_MAKE := $(wildcard $(HOST_PREBUILT)/make$(HOST_EXEEXT))
        endif
       ifndef HOST_PYTHON
            HOST_PYTHON := $(wildcard $(HOST_PREBUILT)/python$(HOST_EXEEXT))
        endif
    endif
else
    $(call ndk_log,Host tools prebuilt directory not found, using system tools)
endif

HOST_ECHO := $(strip $(NDK_HOST_ECHO))
ifdef HOST_PREBUILT
    ifndef HOST_ECHO
        # Special case, on Cygwin, always use the host echo, not our prebuilt one
        # which adds \r\n at the end of lines.
        ifneq ($(HOST_OS),cygwin)
            HOST_ECHO := $(strip $(wildcard $(HOST_PREBUILT)/echo$(HOST_EXEEXT)))
        endif
    endif
endif
ifndef HOST_ECHO
    HOST_ECHO := echo
endif
$(call ndk_log,Host 'echo' tool: $(HOST_ECHO))

# Define HOST_ECHO_N to perform the equivalent of 'echo -n' on all platforms.
ifeq ($(HOST_OS),windows)
  # Our custom toolbox echo binary supports -n.
  HOST_ECHO_N := $(HOST_ECHO) -n
else
  # On Posix, just use bare printf.
  HOST_ECHO_N := printf %s
endif
$(call ndk_log,Host 'echo -n' tool: $(HOST_ECHO_N))

HOST_CMP := $(strip $(NDK_HOST_CMP))
ifdef HOST_PREBUILT
    ifndef HOST_CMP
        HOST_CMP := $(strip $(wildcard $(HOST_PREBUILT)/cmp$(HOST_EXEEXT)))
    endif
endif
ifndef HOST_CMP
    HOST_CMP := cmp
endif
$(call ndk_log,Host 'cmp' tool: $(HOST_CMP))

#
# Verify that the 'awk' tool has the features we need.
# Both Nawk and Gawk do.
#
HOST_AWK := $(strip $(HOST_AWK))
ifndef HOST_AWK
    HOST_AWK := awk
endif
$(call ndk_log,Host 'awk' tool: $(HOST_AWK))

# Location of all awk scripts we use
BUILD_AWK := $(NDK_ROOT)/build/awk

AWK_TEST := $(shell $(HOST_AWK) -f $(BUILD_AWK)/check-awk.awk)
$(call ndk_log,Host 'awk' test returned: $(AWK_TEST))
ifneq ($(AWK_TEST),Pass)
    $(call __ndk_info,Host 'awk' tool is outdated. Please define NDK_HOST_AWK to point to Gawk or Nawk !)
    $(call __ndk_error,Aborting.)
endif

#
# On Cygwin/MSys, define the 'cygwin-to-host-path' function here depending on the
# environment. The rules are the following:
#
# 1/ If NDK_USE_CYGPATH=1 and cygpath does exist in your path, cygwin-to-host-path
#    calls "cygpath -m" for each host path.  Since invoking 'cygpath -m' from GNU
#    Make for each source file is _very_ slow, this is only a backup plan in
#    case our automatic substitution function (described below) doesn't work.
#
# 2/ Generate a Make function that performs the mapping from cygwin/msys to host
#    paths through simple substitutions.  It's really a series of nested patsubst
#    calls, that loo like:
#
#     cygwin-to-host-path = $(patsubst /cygdrive/c/%,c:/%,\
#                             $(patsusbt /cygdrive/d/%,d:/%, \
#                              $1)
#    or in MSys:
#     cygwin-to-host-path = $(patsubst /c/%,c:/%,\
#                             $(patsusbt /d/%,d:/%, \
#                              $1)
#
# except that the actual definition is built from the list of mounted
# drives as reported by "mount" and deals with drive letter cases (i.e.
# '/cygdrive/c' and '/cygdrive/C')
#
ifeq ($(HOST_OS),cygwin)
    CYGPATH := $(strip $(HOST_CYGPATH))
    ifndef CYGPATH
        $(call ndk_log, Probing for 'cygpath' program)
        CYGPATH := $(strip $(shell which cygpath 2>/dev/null))
        ifndef CYGPATH
            $(call ndk_log, 'cygpath' was *not* found in your path)
        else
            $(call ndk_log, 'cygpath' found as: $(CYGPATH))
        endif
    endif

    ifeq ($(NDK_USE_CYGPATH),1)
        ifndef CYGPATH
            $(call __ndk_info,No cygpath)
            $(call __ndk_error,Aborting)
        endif
        $(call ndk_log, Forced usage of 'cygpath -m' through NDK_USE_CYGPATH=1)
        cygwin-to-host-path = $(strip $(shell $(CYGPATH) -m $1))
    else
        # Call an awk script to generate a Makefile fragment used to define a function
        WINDOWS_HOST_PATH_FRAGMENT := $(shell mount | tr '\\' '/' | $(HOST_AWK) -f $(BUILD_AWK)/gen-windows-host-path.awk)
        ifeq ($(NDK_LOG),1)
            $(info Using cygwin substitution rules:)
            $(eval $(shell mount | tr '\\' '/' | $(HOST_AWK) -f $(BUILD_AWK)/gen-windows-host-path.awk -vVERBOSE=1))
        endif
        $(eval cygwin-to-host-path = $(WINDOWS_HOST_PATH_FRAGMENT))
    endif
endif # HOST_OS == cygwin

# The location of the build system files
BUILD_SYSTEM := $(NDK_ROOT)/build/core

# Include default values
include $(BUILD_SYSTEM)/defaults.mk

# Include common definitions
include $(BUILD_SYSTEM)/definitions.mk

# ====================================================================
#
# Read all platform-specific configuration files.
#
# Each platform must be located in build/platforms/android-<apilevel>
# where <apilevel> corresponds to an API level number, with:
#   3 -> Android 1.5
#   4 -> next platform release
#
# ====================================================================

# The platform files were moved in the Android source tree from
# $TOP/ndk/build/platforms to $TOP/development/ndk/platforms. However,
# the official NDK release packages still place them under the old
# location for now, so deal with this here
#
NDK_PLATFORMS_ROOT := $(strip $(NDK_PLATFORMS_ROOT))
ifndef NDK_PLATFORMS_ROOT
    NDK_PLATFORMS_ROOT := $(strip $(wildcard $(NDK_ROOT)/platforms))
    ifndef NDK_PLATFORMS_ROOT
        NDK_PLATFORMS_ROOT := $(strip $(wildcard $(NDK_ROOT)/build/platforms))
    endif

    ifndef NDK_PLATFORMS_ROOT
        $(call __ndk_info,Could not find platform files (headers and libraries))
        $(if $(strip $(wildcard $(NDK_ROOT)/RELEASE.TXT)),\
            $(call __ndk_info,Please define NDK_PLATFORMS_ROOT to point to a valid directory.)\
        ,\
            $(call __ndk_info,Please run build/tools/gen-platforms.sh to build the corresponding directory.)\
        )
        $(call __ndk_error,Aborting)
    endif

    $(call ndk_log,Found platform root directory: $(NDK_PLATFORMS_ROOT))
endif
ifeq ($(strip $(wildcard $(NDK_PLATFORMS_ROOT)/android-*)),)
    $(call __ndk_info,Your NDK_PLATFORMS_ROOT points to an invalid directory)
    $(call __ndk_info,Current value: $(NDK_PLATFORMS_ROOT))
    $(call __ndk_error,Aborting)
endif

NDK_ALL_PLATFORMS := $(strip $(notdir $(wildcard $(NDK_PLATFORMS_ROOT)/android-*)))
$(call ndk_log,Found supported platforms: $(NDK_ALL_PLATFORMS))

$(foreach _platform,$(NDK_ALL_PLATFORMS),\
  $(eval include $(BUILD_SYSTEM)/add-platform.mk)\
)

# we're going to find the maximum platform number of the form android-<number>
# ignore others, which could correspond to special and experimental cases
NDK_PREVIEW_LEVEL := L
NDK_ALL_PLATFORM_LEVELS := $(filter android-%,$(NDK_ALL_PLATFORMS))
NDK_ALL_PLATFORM_LEVELS := $(patsubst android-%,%,$(NDK_ALL_PLATFORM_LEVELS))
ifneq (,$(filter $(NDK_PREVIEW_LEVEL),$(NDK_ALL_PLATFORM_LEVELS)))
    $(call __ndk_info,Please remove stale preview platforms/android-$(NDK_PREVIEW_LEVEL))
    $(call __ndk_info,API level android-L is renamed as android-21.)
    $(call __ndk_error,Aborting)
endif
$(call ndk_log,Found stable platform levels: $(NDK_ALL_PLATFORM_LEVELS))

NDK_MAX_PLATFORM_LEVEL := 3
$(foreach level,$(NDK_ALL_PLATFORM_LEVELS),\
  $(eval NDK_MAX_PLATFORM_LEVEL := $$(call max,$$(NDK_MAX_PLATFORM_LEVEL),$$(level)))\
)

$(call ndk_log,Found max platform level: $(NDK_MAX_PLATFORM_LEVEL))

# ====================================================================
#
# Read all toolchain-specific configuration files.
#
# Each toolchain must have a corresponding config.mk file located
# in build/toolchains/<name>/ that will be included here.
#
# Each one of these files should define the following variables:
#   TOOLCHAIN_NAME   toolchain name (e.g. arm-linux-androideabi-4.9)
#   TOOLCHAIN_ABIS   list of target ABIs supported by the toolchain.
#
# Then, it should include $(ADD_TOOLCHAIN) which will perform
# book-keeping for the build system.
#
# ====================================================================

# the build script to include in each toolchain config.mk
ADD_TOOLCHAIN := $(BUILD_SYSTEM)/add-toolchain.mk

# the list of known abis and archs
NDK_KNOWN_DEVICE_ABI64S := arm64-v8a x86_64 mips64
NDK_KNOWN_DEVICE_ABI32S := armeabi-v7a armeabi x86 mips
NDK_KNOWN_DEVICE_ABIS := $(NDK_KNOWN_DEVICE_ABI64S) $(NDK_KNOWN_DEVICE_ABI32S)
NDK_KNOWN_ABIS     := armeabi-v7a-hard $(NDK_KNOWN_DEVICE_ABIS)
NDK_KNOWN_ABI32S   := armeabi-v7a-hard $(NDK_KNOWN_DEVICE_ABI32S)
NDK_KNOWN_ARCHS    := arm x86 mips arm64 x86_64 mips64
_archs := $(sort $(strip $(notdir $(wildcard $(NDK_PLATFORMS_ROOT)/android-*/arch-*))))
NDK_FOUND_ARCHS    := $(_archs:arch-%=%)

# the list of abis 'APP_ABI=all' is expanded to
ifneq (,$(filter yes all all32 all64,$(_NDK_TESTING_ALL_)))
NDK_APP_ABI_ALL_EXPANDED := $(NDK_KNOWN_ABIS)
NDK_APP_ABI_ALL32_EXPANDED := $(NDK_KNOWN_ABI32S)
else
NDK_APP_ABI_ALL_EXPANDED := $(NDK_KNOWN_DEVICE_ABIS)
NDK_APP_ABI_ALL32_EXPANDED := $(NDK_KNOWN_DEVICE_ABI32S)
endif
NDK_APP_ABI_ALL64_EXPANDED := $(NDK_KNOWN_DEVICE_ABI64S)

# For testing purpose
ifeq ($(_NDK_TESTING_ALL_),all32)
NDK_APP_ABI_ALL_EXPANDED := $(NDK_APP_ABI_ALL32_EXPANDED)
else
ifeq ($(_NDK_TESTING_ALL_),all64)
NDK_APP_ABI_ALL_EXPANDED := $(NDK_APP_ABI_ALL64_EXPANDED)
endif
endif

# The first API level ndk-build enforces -fPIE for executable
NDK_FIRST_PIE_PLATFORM_LEVEL := 16

# the list of all toolchains in this NDK
NDK_ALL_TOOLCHAINS :=
NDK_ALL_ABIS       :=
NDK_ALL_ARCHS      :=

TOOLCHAIN_CONFIGS := $(wildcard $(NDK_ROOT)/toolchains/*/config.mk)
$(foreach _config_mk,$(TOOLCHAIN_CONFIGS),\
  $(eval include $(BUILD_SYSTEM)/add-toolchain.mk)\
)

NDK_ALL_TOOLCHAINS   := $(sort $(NDK_ALL_TOOLCHAINS))
NDK_ALL_ABIS         := $(sort $(NDK_ALL_ABIS))
NDK_ALL_ARCHS        := $(sort $(NDK_ALL_ARCHS))

# Check that each ABI has a single architecture definition
$(foreach _abi,$(strip $(NDK_ALL_ABIS)),\
  $(if $(filter-out 1,$(words $(NDK_ABI.$(_abi).arch))),\
    $(call __ndk_info,INTERNAL ERROR: The $(_abi) ABI should have exactly one architecture definitions. Found: '$(NDK_ABI.$(_abi).arch)')\
    $(call __ndk_error,Aborting...)\
  )\
)

# Allow the user to define NDK_TOOLCHAIN to a custom toolchain name.
# This is normally used when the NDK release comes with several toolchains
# for the same architecture (generally for backwards-compatibility).
#
NDK_TOOLCHAIN := $(strip $(NDK_TOOLCHAIN))
ifdef NDK_TOOLCHAIN
    # check that the toolchain name is supported
    $(if $(filter-out $(NDK_ALL_TOOLCHAINS),$(NDK_TOOLCHAIN)),\
      $(call __ndk_info,NDK_TOOLCHAIN is defined to the unsupported value $(NDK_TOOLCHAIN)) \
      $(call __ndk_info,Please use one of the following values: $(NDK_ALL_TOOLCHAINS))\
      $(call __ndk_error,Aborting)\
    ,)
    $(call ndk_log, Using specific toolchain $(NDK_TOOLCHAIN))
endif

# Allow the user to define NDK_TOOLCHAIN_VERSION to override the toolchain
# version number. Unlike NDK_TOOLCHAIN, this only changes the suffix of
# the toolchain path we're using.
#
# For example, if GCC 4.8 is the default, defining NDK_TOOLCHAIN_VERSION=4.9
# will ensure that ndk-build uses the following toolchains, depending on
# the target architecture:
#
#    arm -> arm-linux-androideabi-4.9
#    x86 -> x86-android-linux-4.9
#    mips -> mipsel-linux-android-4.9
#
# This is used in setup-toolchain.mk
#
NDK_TOOLCHAIN_VERSION := $(strip $(NDK_TOOLCHAIN_VERSION))

$(call ndk_log, This NDK supports the following target architectures and ABIS:)
$(foreach arch,$(NDK_ALL_ARCHS),\
    $(call ndk_log, $(space)$(space)$(arch): $(NDK_ARCH.$(arch).abis))\
)
$(call ndk_log, This NDK supports the following toolchains and target ABIs:)
$(foreach tc,$(NDK_ALL_TOOLCHAINS),\
    $(call ndk_log, $(space)$(space)$(tc):  $(NDK_TOOLCHAIN.$(tc).abis))\
)
