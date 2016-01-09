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

MY_NAME=libjpeg

. `dirname $0`/common-build.sh

my_configure() {
    run ./configure --prefix=$INSTALLDIR \
        --host=$HOST \
        --enable-shared \
        --enable-static \
        --with-pic \
        --disable-ld-version-script \

    fail_panic "Can't configure $ABI libjpeg-$LIBJPEG_VERSION"
}

my_compiler_setup() {
    CFLAGS="$CFLAGS --sysroot=$NDK_DIR/platforms/android-$APILEVEL/arch-$ARCH"

    LDFLAGS=""
    if [ "$ABI" = "armeabi-v7a-hard" ]; then
        LDFLAGS="$LDFLAGS -Wl,--no-warn-mismatch"
    fi
    LDFLAGS="$LDFLAGS -L$NDK_DIR/sources/crystax/libs/$ABI"

    local TCPREFIX=$NDK_DIR/toolchains/${TOOLCHAIN}-4.9/prebuilt/$HOST_TAG

    CC=$BUILDDIR/cc
    {
        echo "#!/bin/bash"
        echo "ARGS="
        echo 'NEXT_ARG_IS_SONAME=no'
        echo "for p in \"\$@\"; do"
        echo '    case $p in'
        echo '        -Wl,-soname)'
        echo '            NEXT_ARG_IS_SONAME=yes'
        echo '            ;;'
        echo '        *)'
        echo '            if [ "$NEXT_ARG_IS_SONAME" = "yes" ]; then'
        echo '                p=$(echo $p | sed "s,\.so.*$,.so,")'
        echo '                NEXT_ARG_IS_SONAME=no'
        echo '            fi'
        echo '    esac'
        echo "    ARGS=\"\$ARGS \$p\""
        echo "done"
        echo "exec $TCPREFIX/bin/${HOST}-gcc \$ARGS"
    } >$CC
    fail_panic "Can't create cc wrapper"
    chmod +x $CC
    fail_panic "Can't chmod +x cc wrapper"

    CPP="$CC $CFLAGS -E"
    AR=$TCPREFIX/bin/${HOST}-ar
    RANLIB=$TCPREFIX/bin/${HOST}-ranlib
    export CC CPP AR RANLIB
    export CFLAGS LDFLAGS
}

build_me "$@"
