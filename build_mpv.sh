#!/bin/bash
set -xe
shopt -s globstar
cd "$(dirname "$0")"
source util/vars.sh

source "variants/${TARGET}-${VARIANT}.sh"

for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

if docker info -f "{{println .SecurityOptions}}" | grep rootless >/dev/null 2>&1; then
    UIDARGS=()
else
    UIDARGS=( -u "$(id -u):$(id -g)" )
fi

rm -rf ffbuild
mkdir ffbuild

MPV_REPO="${MPV_REPO:-https://github.com/mpv-player/mpv.git}"
MPV_REPO="${MPV_REPO_OVERRIDE:-$MPV_REPO}"
MPV_BRANCH="${MPV_BRANCH:-master}"
MPV_BRANCH="${MPV_BRANCH_OVERRIDE:-$MPV_BRANCH}"

GPL_FLAG="false"
[[ "$VARIANT" == gpl* ]] && GPL_FLAG="true"

BUILD_SCRIPT="$(mktemp)"
trap "rm -f -- '$BUILD_SCRIPT'" EXIT

cat <<EOF >"$BUILD_SCRIPT"
    set -xe
    cd /ffbuild
    rm -rf mpv prefix

    export CFLAGS="\${CFLAGS/-I\${FFBUILD_PREFIX}\/include/-isystem\${FFBUILD_PREFIX}/include}"
    export CXXFLAGS="\${CXXFLAGS/-I\${FFBUILD_PREFIX}\/include/-isystem\${FFBUILD_PREFIX}/include}"
    export CFLAGS="\$CFLAGS -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"

    git clone --filter=blob:none --branch='$MPV_BRANCH' '$MPV_REPO' mpv
    cd mpv

    meson setup build --cross-file /cross.meson \\
        --werror \\
        -Dlibmpv=true \\
        -Dtests=true \\
        --buildtype=release \\
        --prefer-static \\
        --default-library=shared \\
        --prefix=/ffbuild/prefix \\
        -Dc_link_args="\$FF_LIBS" \\
        -Dcpp_link_args="\$FF_LIBS" \\
        -Dgpl=$GPL_FLAG \\
        -Dlua=luajit \\
        -Damf=enabled \\
        -Dd3d11=enabled \\
        -Djavascript=enabled \\
        -Dshaderc=enabled \\
        -Dspirvnative-cross=enabled \\
        -Dsubrandr=enabled \\
        -Dvulkan=enabled \\
        -Dwin32-smtc=enabled
    meson compile -C build
    meson install -C build
EOF

[[ -t 1 ]] && TTY_ARG="-t" || TTY_ARG=""

docker run --rm -i $TTY_ARG "${UIDARGS[@]}" -v "$PWD/ffbuild":/ffbuild -v "$BUILD_SCRIPT":/build.sh "$IMAGE" bash /build.sh

mkdir -p artifacts
ARTIFACTS_PATH="$PWD/artifacts"
BUILD_NAME="mpv-$(date +%Y%m%d)-${TARGET}-${VARIANT}"

mkdir -p "ffbuild/pkgroot/$BUILD_NAME/bin"

# mpv executables
cp ffbuild/prefix/bin/mpv* "ffbuild/pkgroot/$BUILD_NAME/bin/" 2>/dev/null || true

# libmpv
if ls ffbuild/prefix/lib/libmpv* 1>/dev/null 2>&1 || ls ffbuild/prefix/bin/libmpv* 1>/dev/null 2>&1; then
    mkdir -p "ffbuild/pkgroot/$BUILD_NAME/lib"
    cp ffbuild/prefix/lib/libmpv* "ffbuild/pkgroot/$BUILD_NAME/lib/" 2>/dev/null || true
    cp ffbuild/prefix/bin/libmpv* "ffbuild/pkgroot/$BUILD_NAME/lib/" 2>/dev/null || true
fi

# headers
if [[ -d ffbuild/prefix/include/mpv ]]; then
    mkdir -p "ffbuild/pkgroot/$BUILD_NAME/include/mpv"
    cp ffbuild/prefix/include/mpv/*.h "ffbuild/pkgroot/$BUILD_NAME/include/mpv/"
fi

# batch files
cp ffbuild/mpv/etc/mpv-*.bat "ffbuild/pkgroot/$BUILD_NAME/bin/" 2>/dev/null || true

cd ffbuild/pkgroot
if [[ "${TARGET}" == win* ]]; then
    OUTPUT_FNAME="${BUILD_NAME}.zip"
    docker run --rm -i $TTY_ARG "${UIDARGS[@]}" -v "${ARTIFACTS_PATH}":/out -v "${PWD}/${BUILD_NAME}":"/${BUILD_NAME}" -w / "$IMAGE" zip -9 -r "/out/${OUTPUT_FNAME}" "$BUILD_NAME"
else
    OUTPUT_FNAME="${BUILD_NAME}.tar.xz"
    docker run --rm -i $TTY_ARG "${UIDARGS[@]}" -v "${ARTIFACTS_PATH}":/out -v "${PWD}/${BUILD_NAME}":"/${BUILD_NAME}" -w / "$IMAGE" tar cJf "/out/${OUTPUT_FNAME}" "$BUILD_NAME"
fi
cd -

rm -rf ffbuild

if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    echo "${OUTPUT_FNAME}" > "${ARTIFACTS_PATH}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.txt"
fi
