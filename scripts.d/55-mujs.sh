#!/bin/bash

SCRIPT_REPO="git://cgit.ghostscript.com/mujs.git"
SCRIPT_COMMIT="HEAD"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "git clone --depth=1 '${SCRIPT_REPO}' . && rm -rf .git"
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --default-library=static
        -Dwerror=false
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --cross-file=/cross.meson
        )
    else
        echo "Unknown target"
        return -1
    fi

    meson setup "${myconf[@]}" ..
    ninja -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja install
}
