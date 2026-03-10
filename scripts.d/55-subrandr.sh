#!/bin/bash

SCRIPT_REPO="https://github.com/afishhh/subrandr.git"
SCRIPT_COMMIT="HEAD"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerdl() {
    echo "git clone --depth=1 '${SCRIPT_REPO}' . && rm -rf .git"
}

ffbuild_dockerbuild() {
    cargo xtask install \
        --prefix "$FFBUILD_PREFIX" \
        --target "$FFBUILD_RUST_TARGET" \
        --static-library true \
        --shared-library false \
        --destdir "$FFBUILD_DESTDIR"
}
