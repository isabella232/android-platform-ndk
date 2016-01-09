#!/bin/bash

# Copyright (c) 2011-2015 CrystaX.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY CrystaX ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CrystaX OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of CrystaX.

# include common function and variable definitions
. `dirname "$0"`/prebuilt-common.sh

parse_options() {
    MY_SUBDIR=${MY_NAME^^}_SUBDIR
    MY_SUBDIR=${!MY_SUBDIR}

    PROGRAM_PARAMETERS="<src-dir>"

    PROGRAM_DESCRIPTION=\
    "Rebuild the prebuilt $MY_NAME binaries for the Android NDK.

    This requires a temporary NDK installation containing platforms and
    toolchain binaries for all target architectures, as well as the path to
    the corresponding $MY_NAME source tree.

    By default, this will try with the current NDK directory, unless
    you use the --ndk-dir=<path> option.

    The output will be placed in appropriate sub-directories of
    <ndk>/$MY_SUBDIR, but you can override this with the --out-dir=<path>
    option.
    "

    PACKAGE_DIR=
    register_var_option "--package-dir=<path>" PACKAGE_DIR "Put prebuilt tarballs into <path>."

    NDK_DIR=$ANDROID_NDK_ROOT
    register_var_option "--ndk-dir=<path>" NDK_DIR "Specify NDK root path for the build."

    BUILD_DIR=
    OPTION_BUILD_DIR=
    register_var_option "--build-dir=<path>" OPTION_BUILD_DIR "Specify temporary build dir."

    OUT_DIR=
    register_var_option "--out-dir=<path>" OUT_DIR "Specify output directory directly."

    ABIS=$(spaces_to_commas $PREBUILT_ABIS)
    register_var_option "--abis=<list>" ABIS "Specify list of target ABIs."

    MY_VERSION=
    register_var_option "--version=<ver>" MY_VERSION "Specify $MY_NAME version to build"

    register_jobs_option

    register_try64_option

    extract_parameters "$@"

    MY_SRCDIR=$(echo $PARAMETERS | sed 1q)
    if [ -z "$MY_SRCDIR" ]; then
        echo "ERROR: Please provide the path to the $MY_NAME source tree. See --help" 1>&2
        exit 1
    fi

    if [ ! -d "$MY_SRCDIR" ]; then
        echo "ERROR: No such directory: '$MY_SRCDIR'" 1>&2
        exit 1
    fi

    if [ -z "$MY_VERSION" ]; then
        echo "ERROR: Please specify $MY_NAME version" 1>&2
        exit 1
    fi

    GITHASH=$(git -C $MY_SRCDIR rev-parse --verify v$MY_VERSION 2>/dev/null)
    if [ -z "$GITHASH" ]; then
        echo "ERROR: Can't find tag v$MY_VERSION in $MY_SRCDIR" 1>&2
        exit 1
    fi

    ABIS=$(commas_to_spaces $ABIS)
}

create_destination_directory() {
    MY_DSTDIR=$NDK_DIR/$MY_SUBDIR/$MY_VERSION
    mkdir -p $MY_DSTDIR
    fail_panic "Can't create $MY_NAME-$MY_VERSION destination directory: $MY_DSTDIR"
}

create_build_directory() {
    if [ -z "$OPTION_BUILD_DIR" ]; then
        BUILD_DIR=$NDK_TMPDIR/build-$MY_NAME
    else
        eval BUILD_DIR=$OPTION_BUILD_DIR
    fi
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    fail_panic "Could not create build directory: $BUILD_DIR"
}

do_prepare_target_build() {
    prepare_target_build
    fail_panic "Could not setup target build"
}

# $1: ABI
# $2: build directory
build_me_for_abi()
{
    local ABI="$1"
    local BUILDDIR="$2"
    local SRCDIR="$BUILDDIR/src"
    local INSTALLDIR="$BUILDDIR/install"
    local APILEVEL ARCH TOOLCHAIN HOST
    dump "Building $MY_NAME-$MY_VERSION $ABI libraries"
    setup_apilevel_by_abi
    setup_arch_by_abi
    setup_toolchain_by_abi
    setup_host_by_abi
    setup_work_directory
    setup_cflags_by_abi
    my_compiler_setup
    my_configure
    my_make
    my_make_install
    my_install_headers
    my_install_libraries
}

setup_apilevel_by_abi() {
    case $ABI in
        armeabi*|x86|mips)
            APILEVEL=9
            ;;
        arm64*|x86_64|mips64)
            APILEVEL=21
            ;;
        *)
            echo "ERROR: Unknown ABI: '$ABI'" 1>&2
            exit 1
    esac
}

setup_arch_by_abi() {
    case $ABI in
        armeabi*)
            ARCH=arm
            ;;
        arm64*)
            ARCH=arm64
            ;;
        x86|x86_64|mips|mips64)
            ARCH=$ABI
            ;;
        *)
            echo "ERROR: Unknown ABI: '$ABI'" 1>&2
            exit 1
    esac
}

setup_toolchain_by_abi() {
    case $ABI in
        armeabi*)
            TOOLCHAIN=arm-linux-androideabi
            ;;
        x86)
            TOOLCHAIN=x86
            ;;
        mips)
            TOOLCHAIN=mipsel-linux-android
            ;;
        arm64-v8a)
            TOOLCHAIN=aarch64-linux-android
            ;;
        x86_64)
            TOOLCHAIN=x86_64
            ;;
        mips64)
            TOOLCHAIN=mips64el-linux-android
            ;;
        *)
            echo "ERROR: Unknown ABI: '$ABI'" 1>&2
            exit 1
    esac
}

setup_host_by_abi() {
    case $ABI in
        armeabi*)
            HOST=arm-linux-androideabi
            ;;
        arm64*)
            HOST=aarch64-linux-android
            ;;
        x86)
            HOST=i686-linux-android
            ;;
        x86_64)
            HOST=x86_64-linux-android
            ;;
        mips)
            HOST=mipsel-linux-android
            ;;
        mips64)
            HOST=mips64el-linux-android
            ;;
        *)
            echo "ERROR: Unknown ABI: '$ABI'" 1>&2
            exit 1
    esac
}

setup_work_directory() {
    rm -Rf $SRCDIR
    run git clone -b v$MY_VERSION $MY_SRCDIR $SRCDIR
    fail_panic "Can't copy $MY_NAME-$MY_VERSION sources to temporary directory"
    cd $SRCDIR
}

setup_cflags_by_abi() {
    CFLAGS=""
    case $ABI in
        armeabi)
            CFLAGS="-march=armv5te -mtune=xscale -msoft-float"
            ;;
        armeabi-v7a)
            CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp"
            ;;
        armeabi-v7a-hard)
            CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mhard-float"
            ;;
    esac

    case $ABI in
        armeabi*)
            CFLAGS="$CFLAGS -mthumb"
    esac
}

my_compiler_setup() {
    false
    fail_panic "No my_compiler_setup() given"
}

my_configure() {
    false
    fail_panic "No my_configure() given"
}

my_make() {
    run make -j$NUM_JOBS
    fail_panic "Can't build $ABI $MY_NAME-$MY_VERSION"
}

my_make_install() {
    run make install
    fail_panic "Can't install $ABI $MY_NAME-$MY_VERSION"
}

my_install_headers() {
    if [ "$MY_HEADERS_INSTALLED" != "yes" ]; then
        log "Install $MY_NAME-$MY_VERSION headers into $MY_DSTDIR"

        run rm -Rf $MY_DSTDIR/include
        run rsync -aL $INSTALLDIR/include $MY_DSTDIR/
        fail_panic "Can't install $ABI $MY_NAME-$MY_VERSION headers"

        MY_HEADERS_INSTALLED=yes
        export MY_HEADERS_INSTALLED
    fi
}

my_install_libraries() {
    log "Install $MY_NAME-$MY_VERSION $ABI libraries into $MY_DSTDIR"
    run mkdir -p $MY_DSTDIR/libs/$ABI
    fail_panic "Can't create $MY_NAME-$MY_VERSION target $ABI libraries directory"

    local LIBSUFFIX
    for LIBSUFFIX in a so; do
        rm -f $MY_DSTDIR/libs/$ABI/lib*.$LIBSUFFIX
        for f in $(find $INSTALLDIR -name "lib*.$LIBSUFFIX" -print); do
            run rsync -aL $f $MY_DSTDIR/libs/$ABI
            fail_panic "Can't install $ABI $MY_NAME-$MY_VERSION libraries"
        done
    done
}

header_need_package() {
    if [ -n "$PACKAGE_DIR" ]; then
        PACKAGE_NAME="$MY_NAME-$MY_VERSION-headers.tar.xz"
        echo "Look for: $PACKAGE_NAME"
        try_cached_package "$PACKAGE_DIR" "$PACKAGE_NAME" no_exit
        if [ $? -eq 0 ]; then
            MY_HEADERS_NEED_PACKAGE=no
        else
            MY_HEADERS_NEED_PACKAGE=yes
        fi
    fi
}

build_me_for_all_abis() {
    BUILT_ABIS=""
    for ABI in $ABIS; do
        DO_BUILD_PACKAGE=yes
        if [ -n "$PACKAGE_DIR" ]; then
            PACKAGE_NAME="$MY_NAME-$MY_VERSION-libs-$ABI.tar.xz"
            echo "Look for: $PACKAGE_NAME"
            try_cached_package "$PACKAGE_DIR" "$PACKAGE_NAME" no_exit
            if [ $? -eq 0 ]; then
                if [ "$MY_HEADERS_NEED_PACKAGE" = "yes" -a -z "$BUILT_ABIS" ]; then
                    BUILT_ABIS="$BUILT_ABIS $ABI"
                else
                    DO_BUILD_PACKAGE=no
                fi
            else
                BUILT_ABIS="$BUILT_ABIS $ABI"
            fi
        fi
        if [ "$DO_BUILD_PACKAGE" = "yes" ]; then
            build_me_for_abi "$ABI" "$BUILD_DIR/$ABI"
        fi
    done
}

package_into_tarballs() {
    # If needed, package files into tarballs
    if [ -n "$PACKAGE_DIR" ]; then
        if [ "$MY_HEADERS_NEED_PACKAGE" = "yes" ]; then
            FILES="$MY_SUBDIR/$MY_VERSION/include"
            PACKAGE_NAME="$MY_NAME-$MY_VERSION-headers.tar.xz"
            PACKAGE="$PACKAGE_DIR/$PACKAGE_NAME"
            dump "Packaging: $PACKAGE"
            pack_archive "$PACKAGE" "$NDK_DIR" "$FILES"
            fail_panic "Can't package $MY_NAME-$MY_VERSION headers!"
            cache_package "$PACKAGE_DIR" "$PACKAGE_NAME"
        fi

        for ABI in $BUILT_ABIS; do
            FILES="$MY_SUBDIR/$MY_VERSION/libs/$ABI"
            PACKAGE_NAME="$MY_NAME-$MY_VERSION-libs-$ABI.tar.xz"
            PACKAGE="$PACKAGE_DIR/$PACKAGE_NAME"
            dump "Packaging: $PACKAGE"
            pack_archive "$PACKAGE" "$NDK_DIR" "$FILES"
            fail_panic "Can't package $ABI $MY_NAME-$MY_VERSION libraries!"
            cache_package "$PACKAGE_DIR" "$PACKAGE_NAME"
        done
    fi
}

cleanup() {
    if [ -z "$OPTION_BUILD_DIR" ]; then
        log "Cleaning up..."
        rm -Rf $BUILD_DIR
    else
        log "Don't forget to cleanup: $BUILD_DIR"
    fi
}

build_me() {
    parse_options "$@"
    create_destination_directory
    create_build_directory
    do_prepare_target_build
    header_need_package
    build_me_for_all_abis
    package_into_tarballs
    cleanup
    log "Done!"
}
