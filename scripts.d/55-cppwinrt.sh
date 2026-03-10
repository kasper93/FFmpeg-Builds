#!/bin/bash

CPPWINRT_VER="2.0.250303.1"
WINDOWS_RS_VER="73"

ffbuild_enabled() {
    [[ $TARGET == win* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    cat <<EOF
        wget -q "https://github.com/microsoft/cppwinrt/archive/${CPPWINRT_VER}.tar.gz" -O cppwinrt.tar.gz
        wget -q "https://github.com/microsoft/windows-rs/archive/${WINDOWS_RS_VER}.tar.gz" -O windows-rs.tar.gz
        tar -xzf cppwinrt.tar.gz
        tar -xzf windows-rs.tar.gz
        rm -f cppwinrt.tar.gz windows-rs.tar.gz
EOF
}

ffbuild_dockerbuild() {
    mkdir -p "cppwinrt-$CPPWINRT_VER/build"
    cd "cppwinrt-$CPPWINRT_VER/build"

    CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" \
        cmake -GNinja -DCMAKE_CXX_COMPILER="$HOST_CXX" \
              -DCMAKE_BUILD_TYPE=Release \
              -DCPPWINRT_BUILD_VERSION="$CPPWINRT_VER" ..
    ninja cppwinrt

    ./cppwinrt -input "../../windows-rs-$WINDOWS_RS_VER/crates/libs/bindgen/default" \
               -output "$FFBUILD_DESTPREFIX/include"
}
