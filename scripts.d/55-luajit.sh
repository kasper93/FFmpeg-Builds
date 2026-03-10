#!/bin/bash

SCRIPT_REPO="https://github.com/LuaJIT/LuaJIT.git"
SCRIPT_COMMIT="v2.1"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "git clone --depth=1 --branch='${SCRIPT_COMMIT}' '${SCRIPT_REPO}' . && rm -rf .git"
}

ffbuild_dockerbuild() {
    # LuaJIT's install target doesn't really support cross-compilation, apply minor patches.
    sed -i "s|^prefix=/usr/local|prefix=${FFBUILD_PREFIX}|" etc/luajit.pc
    # Strip -ldl, not needed for Windows.
    if [[ $TARGET == win* ]]; then
        sed -i "/^Libs\.private/d" etc/luajit.pc
    fi

    local myconf=(
        PREFIX="$FFBUILD_PREFIX"
        BUILDMODE=static
        XCFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT
    )

    if [[ $TARGET == win* ]]; then
        myconf+=(
            TARGET_SYS=Windows
            HOST_CC="$HOST_CC"
            "CFLAGS=$HOST_CFLAGS"
            CROSS="${FFBUILD_TOOLCHAIN}-"
            "TARGET_CFLAGS=$CFLAGS"
            FILE_T=luajit.exe
            INSTALL_DEP=src/luajit.exe
        )
    elif [[ $TARGET == linux* ]]; then
        myconf+=(
            TARGET_SYS=Linux
            HOST_CC="$HOST_CC"
            "CFLAGS=$HOST_CFLAGS"
            CROSS="${FFBUILD_TOOLCHAIN}-"
            "TARGET_CFLAGS=$CFLAGS"
        )
    else
        echo "Unknown target"
        return -1
    fi

    make "${myconf[@]}" amalg -j$(nproc)
    make "${myconf[@]}" install DESTDIR="$FFBUILD_DESTDIR"
}
