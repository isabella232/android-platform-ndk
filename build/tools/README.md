This directory contains a number of shell scripts, which we will
call the "dev-scripts", that are only used to develop the NDK
itself, i.e. they are not needed when using ndk-build to build
applicative native code.

Their purpose is to handle various sophisticated issues:

 * Rebuilding host cross-toolchains for our supported CPU ABIs.

 * Rebuilding other required host tools (e.g. ndk-stack) from sources.

 * Rebuilding all target-specific prebuilt binaries from sources (this requires
   working host cross-toolchains).

 * Packaging final NDK release tarballs, including adding samples and
   documentation which normally live in $NDK/../development/ndk.

This document is here to explain how to use these dev-scripts and how everything
is architected / designed, in case you want to maintain it.

Generally, everything dev-script supports the --help option to display a
description of the program and the list of all supported options. Also, debug
traces can be activated by using the --verbose option. Use it several times to
increase the level of verbosity.

Note that all Windows host programs can be built on Linux if you have the
`mingw32` cross-toolchain installed (`apt-get install mingw32` on Debian or
Ubuntu). You will need to add the `--mingw` option when invoking the script.

All dev-scripts rebuilding host programs on Linux and Darwin will only generate
32-bit programs by default. You can experiment with 64-bit binary generation by
adding the `--try-64` option. Note that as of now, 64-bit binaries are never
distributed as part of official NDK releases.

When building 32-bit Linux host programs, the dev-scripts will look for
`$ANDROID_BUILD_TOP/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.11-4.8`,
which is part of the Android platform source tree. It is a special toolchain
that ensures that the generated programs can run on old systems like Ubuntu 8.04
that only have GLibc 2.7. Otherwise, the corresponding binaries may not run due
to ABI changes in more recent versions of GLibc.

I. Organization:
================

First, a small description of the NDK's overall directory structure:

build/core
----------

Contains the main NDK build system used when `ndk-build`. Relies heavily on GNU
Make 3.81+ but isn't used by any of the scripts described here.

build/tools
-----------

Contains all the dev-scripts that are described in this document. More on this
later.

sources/host-tools
------------------

Contains sources of various libraries or programs that will be compiled to
generate useful host programs for the final NDK installation. For example,
$NDK/sources/host-tools/ndk-stack/ contains the sources of the `ndk-stack`
program.

sources/cxx-stl
---------------

Contains the sources of various C++ runtime and libraries that can be used with
`ndk-build`. See docs/CPLUSPLUS-SUPPORT.html for more details.

sources/cxx-stl/gabi++
----------------------

Contains the sources of the GAbi++ C++ runtime library. Note that the dev-script
`build-cxx-stl.sh` can be used to generate prebuilt libraries from these
sources, that will be copied under this directory.

sources/cxx-stl/stlport
-----------------------

Contains the sources of a port of STLport that can be used with `ndk-build`. The
dev-script `build-cxx-stl.sh` can be used to generate prebuilt libraries from
these sources, that will be copied under this directory.

sources/cxx-stl/llvm-libc++
---------------------------

Contains the sources of a port of LLVM's libc++ that can be used with ndk-build.
The dev-script `build-cxx-stl.sh` can be used to generate prebuilt libraries
from these sources, that will be copied under this directory.

sources/cxx-stl/gnu-libstdc++
-----------------------------

This directory doesn't contain sources at all, only an Android.mk. The
dev-script `build-gnu-libstdc++.sh` is used to generate prebuilt libraries from
the sources that are located in the toolchain source tree instead.

sources/cxx-stl/system
----------------------

This directory contains a few headers used to use the native system Android C++
runtime (with _very_ limited capabilities), a.k.a. /system/lib/libstdc++.so. The
prebuilt version of this library is generated by the `gen-platform.sh`
dev-script described later, but it never placed in this directory.

sources/android/libthread\_db
-----------------------------

This directory contains the sources of the libthread\_db implementation that is
linked into the prebuilt target gdbserver binary.

sources
-------

The rest of `sources` is used to store the sources of helper libraries used with
`ndk-build`. For example, the `cpu-features` helper library is under
`sources/android/cpu-features`.

$DEVNDK a.k.a $NDK/../development/ndk
-------------------------------------

This directory contains platform-specific files. The reason why it it is
separate from $NDK is because it is not primarily developed in the open.

More specifically:

 * All $NDK development happens in the public AOSP repository ndk.git.

 * Any $DEVNDK development that happens in the public AOSP development.git
   repository is auto-merged to the internal tree maintained by Google.

 * $DEVNDK developments that are specific to an yet-unreleased version of the
   system happen only in the internal tree. They get back-ported to the public
   tree only when the corresponding system release is open-sourced.

$DEVNDK/platforms/android-$PLATFORM
-----------------------------------

Contains all files that are specific to a given API level `$PLATFORM`, that were
not already defined for the previous API level.

For example, android-3 corresponds to Android 1.5, and android-4 corresponds to
Android 1.6. The platforms/android-4 directory only contains files that are
either new or modified, compared to android-3.

$DEVNDK/platforms/android-$PLATFORM/include
-------------------------------------------

Contains all system headers exposed by the NDK for a given platform. All these
headers are independent from the CPU architecture of target devices.

$DEVNDK/platforms/android-$PLATFORM/arch-$ARCH
----------------------------------------------

Contains all files that are specific to a given $PLATFORM level and a specific
CPU architecture. $ARCH is typically 'arm' or 'x86'

$DEVNDK/platforms/android-$PLATFORM/arch-$ARCH/include
------------------------------------------------------

Contains all the architecture-specific headers for a given API level.

$DEVNDK/platforms/android-$PLATFORM/arch-$ARCH/lib
--------------------------------------------------

Contains several CPU-specific object files and static libraries that are
required to build the host cross-toolchains properly.

Before NDK r7, this also contains prebuilt system shared libraries that had been
hand-picked from various platform builds. These have been replaced by symbol
list files instead (see below).

$DEVNDK/platforms/android-$PLATFORM/arch-$ARCH/symbols
------------------------------------------------------

Contains, for each system shared library exposed by the NDK, two files
describing the dynamic symbols it exports, for example, for the C library:

    libc.so.functions.txt -> list of exported function names
    libc.so.variables.txt -> list of exported variable names

These files were introduced in NDK r7 and are used to generate stub shared
libraries that can be used by ndk-build at link time. These shared libraries
contain the same symbols that make the NDK ABI for the given version, but do not
function.

These files can be generated from a given platform build using the
`dev-platform-import.sh` dev-script, described later in this document.

This is handy to compare which symbols were added between platform releases (and
check that nothing disappeared).

$DEVNDK/platforms/android-$PLATFORM/samples
-------------------------------------------

Contains samples that are specific to a given API level. These are
usually copied into $INSTALLED\_NDK/samples/ by the `gen-platforms.sh`
script.

$NDK/platforms
--------------

Not to be confused with $DEVNDK/platforms/, this directory is not part of the
NDK git directory (and is specifically listed in $NDK/.gitignore) but of its final
installation.

Its purpose is to hold the fully expanded platform-specific files. This means
that, unlike $DEVNDK/platforms/android-$PLATFORM, the
$NDK/platforms/android-$PLATFORM will contain _all_ the files that are specific
to API level $PLATFORM.

Moreover, the directory is organized slightly differently, i.e. as toolchain
sysroot, i.e. for each supported $PLATFORM and $ARCH values, it provides two
directories:

    $NDK/platforms/android-$PLATFORM/arch-$ARCH/usr/include
    $NDK/platforms/android-$PLATFORM/arch-$ARCH/usr/lib

Notice the `usr` subdirectory here. It is required by GCC to be able to use the
directories with --with-sysroot. For example, to generate binaries that target
API level 5 for the arm architecture, one would use:

    $TOOLCHAIN_PREFIX-gcc --with-sysroot=$NDK/platforms/android-5/arch-arm

Where `$TOOLCHAIN_PREFIX` depends on the exact toolchain being used.

The dev-script `gen-platforms.sh` is used to populate $NDK/platforms. Note that
by default, the script does more, see its detailed description below.

II. Host toolchains:
====================

The host toolchains are the compiler, linker, debugger and other crucial
programs used to generate machine code for the target Android system supported
by the NDK.

II.1 Getting the toolchain sources:
-----------------------------------

The AOSP toolchain/ repository contains the source for the toolchains used to
build the Android platform and in the NDK.

The master-ndk branch of AOSP contains an already checked out and patched
version of the toolchain repository at toolchain/. The old process of using
download-toolchain-sources.sh is now obsolete.

The toolchains binaries are typically placed under the directory
$NDK/toolchains/$NAME/prebuilt/$SYSTEM, where $NAME is the toolchain name's full
name (e.g. arm-linux-androideabi-4.8), and $SYSTEM is the name of the host
system it is meant to run on (e.g. `linux-x86`, `windows` or `darwin-x86`)

I.2. Building the toolchains:
-----------------------------

First you will need to build a proper "sysroot" directory before being able to
configure/build them.

A sysroot is a directory containing system headers and libraries that the
compiler will use to build a few required target-specific binaries (e.g.
libgcc.a)

To do that, use:

    $NDK/build/tools/gen-platforms.sh --minimal

This will populate $NDK/platforms/ with just the files necessary to rebuild the
toolchains. Note that without the --minimal option, the script will fail without
prebuilt toolchain binaries.

Once the sysroots are in place, use `build-gcc.sh` by providing the path to the
toolchain sources root directory, a destination NDK installation directory to
build, and the full toolchain name.

For example, to rebuild the arm and x86 prebuilt toolchain binaries in the
current NDK directory (which can be handy if you want to later use them to
rebuild other target prebuilts or run tests), do:

    $NDK/build/tools/build-gcc.sh /tmp/ndk-$USER/src $NDK \
        arm-linux-androideabi-4.8
    $NDK/build/tools/build-gcc.sh /tmp/ndk-$USER/src $NDK x86-4.8

Here, we assume you're using the master-ndk branch as described in the previous
section.

This operation can take some time. The script automatically performs a parallel
build to speed up the build on multi-core machine (use the -j<number> option to
control this), but the GCC sources are very large, so expect to wait a few
minutes.

For the record, on a 2.4 GHz Xeon with 16 Hyper-threaded cores and 12GB of
memory, rebuilding each toolchain takes between 2 and 4 minutes.

You need to be on Linux to build the Windows binaries, using the "mingw32"
cross-toolchain (install it with "apt-get install mingw32" on Ubuntu). To do so
use the "--mingw" option, as in:

    $NDK/build/tools/build-gcc.sh --mingw \
        /tmp/ndk-$USER/src $NDK arm-linux-androideabi-4.8

    $NDK/build/tools/build-gcc.sh --mingw \
        /tmp/ndk-$USER/src $NDK x86-4.8

The corresponding binaries are installed under
$NDK/toolchains/$NAME/prebuilt/windows Note that these are native Windows
programs, not Cygwin ones.

Building the Windows toolchains under MSys and Cygwin is completely unsupported
and highly un-recommended: even if it works, it will probably take several
hours, even on a powerful machine :-(

The Darwin binaries must be generated on a Darwin machine. Note that the script
will try to use the 10.5 XCode SDK if it is installed on your system. This
ensures that the generated binaries run on Leopard, even if you're building on a
more recent version of the system.

Once you've completed your builds, you should be able to generate the other
target-specific prebuilts.

III. Target-specific prebuilt binaries:
=======================================

A final NDK installation comes with a lot of various target-specific prebuilt
binaries that must be generated from sources once you have working host
toolchains.

III.1.: Preparation of platform sysroots:
-----------------------------------------

Each target prebuilt is handled by a specific dev-script. HOWEVER, all these
script require that you generate a fully populated $NDK/platforms/ directory
first. To do that, simply run:

    $NDK/gen-platforms.sh

Note that we used this script with the --minimal option to generate the host
toolchains. That's because without this flag, the script will also auto-generate
tiny versions of the system shared libraries that will be used at link-time when
building our target prebuilts.

III.2.: Generation of gdbserver:
---------------------------------

A target-specific `gdbserver` binary is required. This is a small program that
is run on the device through `ndk-gdb` during debugging. For a variety of
technical reasons, it must be copied into a debuggable project's output
directory when `ndk-build` is called.

The prebuilt binary is placed under $NDK/toolchains/$NAME/prebuilt/gdbserver in
the final NDK installation. You can generate with `build-gdbserver.sh` and takes
the same parameters than `build-gcc.sh`. So one can do:

    $NDK/build/tools/build-gcc.sh /tmp/ndk-$USER/src $NDK \
        arm-linux-androideabi-4.8
    $NDK/build/tools/build-gcc.sh /tmp/ndk-$USER/src $NDK x86-4.8


III.3. Generating C++ runtime prebuilt binaries:
-----------------------------------------------

Sources and support files for several C++ runtimes / standard libraries are
provided under $NDK/sources/cxx-stl/. Several dev-scripts are provided to
rebuild their binaries. The scripts place them to their respective location
(e.g. the GAbi++ binaries will go to $NDK/sources/cxx-stl/gabi++/libs/) unless
you use the --out-dir=<path> option.

Note that:

 * Each script will generate the binaries for all the CPU ABIs supported by the
   NDK, e.g. armeabi, armeabi-v7a, x86 and mips. You can restrict them using the
   --abis=<list> option though.

 - The GNU libstdc++ dev-script requires the path to the toolchain sources,
   since this is where the library's sources are located.

An example usage would be:

    $NDK/build/tools/build-cxx-stl.sh --stl=gabi++
    $NDK/build/tools/build-cxx-stl.sh --stl=stlport
    $NDK/build/tools/build-cxx-stl.sh --stl=libc++
    $NDK/build/tools/build-gnu-libstdc++.sh /tmp/ndk-$USER/src

Note that generating the STLport and GNU libstdc++ binaries can take a few
minutes. You can follow the build by using the --verbose option to display
what's going on.

IV. Other host prebuilt binaries:
=================================

There are a few other host prebuilt binaries that are needed for a full NDK
installation. Their sources are typically installed under
$NDK/sources/host-tools/

Note that the corresponding dev-script recognize the --mingw and --try-64
options described at the end of section I above.

IV.1.: Building `ndk-stack`:
---------------------------

The `build-ndk-stack.sh` script can be used to rebuild the `ndk-stack` helper
host program. See docs/NDK-STACK.html for a usage description.  To build it,
just do:

    $NDK/build/tools/build-ndk-stack.sh

IV.2.: Building `ndk-depends`:
-----------------------------

Similar to `ndk-stack`, see the `build-ndk-depends.sh` script.

V. Packaging all prebuilts:
===========================

Generating all the prebuilt binaries takes a lot of time and is no fun.  To
avoid doing it again and again, it is useful to place all the generated files
aside in special tarballs.

Most dev-scripts generating them typically support a --package-dir=<path> option
to do this, where <path> points to a directory that will store compressed
tarballs of the generated binaries.

For example, to build and package the GAbi++ binaries, use:

    $NDK/build/tools/build-cxx-stl.sh --stl=gabi++ \
        --package-dir=/tmp/ndk-$USER/prebuilt/

In NDK r7, this will actually create three tarballs (one per supported ABI),
under the directory /tmp/ndk-$USER/prebuilt/, i.e.:

 * gabixx-libs-armeabi.tar.bz2
 * gabixx-libs-armeabi-v7a.tar.bz2
 * gabixx-libs-x86.tar.bz2
 * ...

Note that these tarballs are built to be uncompressed from the top-level of an
existing NDK install tree.

Similarly, to rebuild the STLport binaries and package them:

    $NDK/build/tools/build-cxx-stl.sh --stl=stlport \
        --package-dir=/tmp/ndk-$USER/prebuilt

A dev-script is provided to rebuild _and_ package all prebuilts. It is called
`rebuild-all-prebuilt.sh`. Note that by default, it will automatically place the
prebuilt tarballs under /tmp/ndk-$USER/prebuilt-$DATE, where $DATE is the
current date in ISO order.

By default, this only rebuilds the host prebuilts for the current host system.
You can use --mingw to force the generation of Windows binaries on Linux.

Additionally, you can use the --darwin-ssh=<hostname> option to launch the build
of the Darwin binaries from a Linux machine, by using ssh to access a remote
Darwin machine. The script will package all required sources into a temporary
tarball, copy it to the remote machine, launch the build there, then copy back
all binaries to your own machine.

This means that it is possible to generate the host binaries for all supported
host systems from Linux (provided you have ssh access to a Darwin machine).

Alternatively, you can run `rebuild-all-prebuilt.sh` on a Darwin machine.

Once you have used the script three times (once per supported host systems), you
should have plenty of files under /tmp/ndk-$USER/prebuilt-$DATE.  For the
record, with NDK r7, the list was:

VI. Packaging NDK releases:
===========================

Use the `package-release.sh` dev-script to generate full NDK release packages.
These contain everything needed by a typical NDK user, including:

 * All prebuilt binaries (host toolchains, host tools, target libs, etc...).
 * All samples (including those collected from $DEVNDK/platforms/).
 * All documentation.

You need to have a directory containing prebuilt tarballs, as described in the
previous section. You can use it as:

    $NDK/build/tools/package-release.sh \
        --release=<name> \
        --systems=<list> \
        --arch=<list> \
        --prebuilt-dir=<path>

The --release option is optional and allows you to provide a name for your
generated NDK archive. More specifically, the archive file name will be
something like android-ndk-$RELEASE-$SYSTEM.tar.bz2, where $RELEASE is the
release name, and $SYSTEM the supported host system (e.g. linux-x86).

By default, i.e. without the option, $RELEASE will be set to the current $DATE.

The --systems=<list> is optional, but can be used to limit the number of host
systems you want to generate for. <list> must be a comma-separated list of
system names (from `linux-x86`, `windows` and `darwin-x86`). This is useful if
you're working on a experimental feature and don't have the time to regenerate
the host toolchains for all systems. It allows you to generate an experimental
package that you can distribute to third-party for experimentation.

By default, i.e. without the option, the scripts tries to build NDK archives for
all supported host systems.

The --arch=<list> is also optional, but can be used to limit the number of
target architectures you want to generate for. <list> must be a comma-separated
list of CPU architectures (e.g. from `arm` and `x86`). Without the option, this
will try to build packages that support all architectures.

Finally, --prebuilt-dir=<path> must point to the directory that contains the
prebuilt tarballs described in section V. Following our previous example, one
could use --prebuilt-dir=/tmp/ndk-$USER/prebuilt here.

VI. Testing:
============

The $NDK/tests directory contains a number of NDK unit-tests that can be used to
verify that the generated NDK packages or the working NDK tree still behave
correctly.

If you have an NDK package archive, you can run the following to run the test
suite against it:

    $NDK/tests/run-tests.sh --package=<ndk-archive>

This will uncompress the NDK archive in a temporary directory, then run all the
tests with it. When all tests have run, the temporary directory is removed
automatically.

You can also point to an existing NDK installation with --ndk=<path>, as in:

    $NDK/tests/run-tests.sh --ndk=<path>

Where <path> points to another NDK installation. The script will run the test
suite present under $NDK/tests/, not the one in the remote NDK directory.

If you don't use any option, the test suite will be run with the current NDK
directory. This can only work if you have generated or unpacked all prebuilt
archives into it before that.

You can get more traces from the tests by using --verbose. Use it twice to see
even more traces.

There are several kinds of tests:

 * 'build tests' are used to test the building capabilities of the NDK.
   I.e. the tests will only use them to check that the NDK build system
   didn't regress. The corresponding generated binaries are never used
   otherwise.

 * 'device tests' are used to test both the build and the behaviour of
   the generated code. If the `adb` program is in your path, and have
   one device or emulator connected to your host machine, `run-tests.sh`
   will automatically upload, run and cleanup these tests for you.

   If adb is not in your path, or no device is connected, run-tests.sh
   will simply print a warning and carry on.


Whenever you add a feature to the NDK, or fix a bug, it is recommended to add a
unit test to check the feature or the fix. Use $NDK/tests/build for build tests,
and $NDK/tests/device for device tests.
