# Check if ARM g++ no longer gives pointless warning about the mangling of <va_list> has changed in GCC 4.4
# See https://android-review.googlesource.com/#/c/42274/
#

export ANDROID_NDK_ROOT=$NDK

NDK_BUILDTOOLS_PATH=$NDK/build/tools
. $NDK/build/tools/prebuilt-common.sh

VERSION=4.9

if [ -n "$NDK_TOOLCHAIN_VERSION" ];  then
    case "$NDK_TOOLCHAIN_VERSION" in
        clang*)
           echo "No need to test clang on this issue"
           exit 0
            ;;
        *)
           VERSION=$NDK_TOOLCHAIN_VERSION
    esac
fi

SYSTEM=$(get_prebuilt_host_tag)
case $SYSTEM in
    windows|cygwin*)
        SYSTEM=windows
        SYSTEM64=windows-x86_64
        NULL="NUL"
        ;;
    *)
        SYSTEM64=${SYSTEM}_64
        NULL="/dev/null"
esac

ARM_GPP=$NDK/toolchains/arm-linux-androideabi-$VERSION/prebuilt/$SYSTEM/bin/arm-linux-androideabi-g++${HOST_EXE}
if [ ! -f "$ARM_GPP" ]; then
    ARM_GPP=$NDK/toolchains/arm-linux-androideabi-$VERSION/prebuilt/$SYSTEM64/bin/arm-linux-androideabi-g++${HOST_EXE}
fi
if [ ! -f "$ARM_GPP" ]; then
    echo "ERROR: Can't locate compiler $ARM_GPP"
    exit 1
fi

OUT=$(echo "#include <stdarg.h>
void foo(va_list v) { }" | $ARM_GPP -x c++ -c -o $NULL - 2>&1)

if [ -z "$OUT" ]; then
  echo "ARM g++ no longer gives pointless warning about the mangling of <va_list> has changed in GCC 4.4"
  exit 0
else
  echo "ERROR: ARM g++ still gives pointless warning about the mangling of <va_list> has changed in GCC 4.4"
  exit 1
fi
