#!/bin/bash

SCRIPT_REPO="https://github.com/FFmpeg/FFmpeg.git"
SCRIPT_COMMIT="master"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "git clone --filter=blob:none --branch='${SCRIPT_COMMIT}' '${SCRIPT_REPO}' . && rm -rf .git"
}

ffbuild_dockerbuild() {
    # FF_CONFIGURE, FF_CFLAGS, etc. are inherited as ENV vars from the base image
    # (the FFmpeg variant image that already has all library deps installed).

    ./configure --prefix="$FFBUILD_PREFIX" --pkg-config-flags="--static" \
        $FFBUILD_TARGET_FLAGS $FF_CONFIGURE \
        --extra-cflags="$FF_CFLAGS" \
        --extra-cxxflags="$FF_CXXFLAGS" \
        --extra-libs="$FF_LIBS" \
        --extra-ldflags="$FF_LDFLAGS" \
        --extra-ldexeflags="$FF_LDEXEFLAGS" \
        --cc="$CC" --cxx="$CXX" \
        --ar="$AR" --ranlib="$RANLIB" --nm="$NM" \
        --enable-static --disable-shared \
        --disable-debug --disable-doc \
        --extra-version="$(date +%Y%m%d)"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"

    # Copy FFmpeg binaries to libexec/ so they survive run_stage.sh's
    # "rm -rf $FFBUILD_DESTPREFIX/bin" cleanup. mpv tests need ffmpeg.exe.
    if [[ -d "$FFBUILD_DESTPREFIX/bin" ]]; then
        mkdir -p "$FFBUILD_DESTPREFIX/libexec"
        cp -a "$FFBUILD_DESTPREFIX/bin"/* "$FFBUILD_DESTPREFIX/libexec/"
    fi
}
