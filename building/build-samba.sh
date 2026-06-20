#!/bin/sh
set -eu

SAMBA_VERSION=4.24.3
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
HOSTCC_PATCH="$SCRIPT_DIR/samba-$SAMBA_VERSION-hostcc.patch"

: "${SAMBA_SOURCE:?Set SAMBA_SOURCE to the unpacked Samba ${SAMBA_VERSION} source directory}"
: "${TOOLDIR:?Set TOOLDIR to the NetBSD cross-tool directory}"
: "${SYSROOT:?Set SYSROOT to the NetBSD 6 evbarm DESTDIR/sysroot}"
: "${TRIPLE:?Set TRIPLE to the target compiler prefix, for example arm--netbsdelf-eabi}"
: "${PREFIX:?Set PREFIX to the staging directory shared with build-prereqs.sh}"
: "${CROSS_ANSWERS:?Set CROSS_ANSWERS to the reviewed Waf cross-answers file}"

case "$(basename "$SAMBA_SOURCE")" in
    samba-$SAMBA_VERSION) ;;
    *)
        echo "Refusing unsupported source tree: expected samba-$SAMBA_VERSION" >&2
        exit 2
        ;;
esac

for path in \
    "$TOOLDIR/bin/$TRIPLE-gcc" \
    "$TOOLDIR/bin/$TRIPLE-ar" \
    "$TOOLDIR/bin/$TRIPLE-ranlib" \
    "$CROSS_ANSWERS" \
    "$HOSTCC_PATCH"
do
    test -e "$path" || { echo "Missing required build input: $path" >&2; exit 2; }
done

mkdir -p "$PREFIX"
if test -e "$PREFIX/samba-min"; then
    echo "Refusing to overwrite existing staged Samba tree: $PREFIX/samba-min" >&2
    exit 2
fi

export PATH="$TOOLDIR/bin:/usr/pkg/bin:$PATH"
export CC="$TOOLDIR/bin/$TRIPLE-gcc --sysroot=$SYSROOT"
export CXX="$TOOLDIR/bin/$TRIPLE-g++ --sysroot=$SYSROOT"
export AR="$TOOLDIR/bin/$TRIPLE-ar"
export RANLIB="$TOOLDIR/bin/$TRIPLE-ranlib"
export STRIP="$TOOLDIR/bin/$TRIPLE-strip"
export CFLAGS="${CFLAGS:--Os -fno-ident}"
export CPPFLAGS="${CPPFLAGS:--I$PREFIX/include -I$SYSROOT/usr/include -D_NETBSD_SOURCE -D_INCOMPLETE_XOPEN_C063 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES}"
export LDFLAGS="${LDFLAGS:---sysroot=$SYSROOT -L$PREFIX/lib -L$SYSROOT/lib -L$SYSROOT/usr/lib}"
export PKG_CONFIG_DIR=
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-$PREFIX/lib/pkgconfig}"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:-$PREFIX/lib/pkgconfig}"
export PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR:-}"

cd "$SAMBA_SOURCE"
PATCH_ID=$(cksum "$HOSTCC_PATCH")
PATCH_STAMP=".timecapsule-samba-$SAMBA_VERSION.patch-id"
if test -f "$PATCH_STAMP"; then
    test "$(cat "$PATCH_STAMP")" = "$PATCH_ID" || {
        echo "Compatibility patch changed; start from a fresh Samba source tree" >&2
        exit 2
    }
else
    if grep -q 'def SAMBA_HOSTCC_ENV' buildtools/wafsamba/wafsamba.py; then
        echo "Source tree is patched but has no matching patch stamp; start fresh" >&2
        exit 2
    fi
    patch -p1 < "$HOSTCC_PATCH"
    printf '%s\n' "$PATCH_ID" > "$PATCH_STAMP"
fi
rm -rf bin .waf-* .lock-waf* config.log

./configure \
    --cross-compile \
    --cross-answers="$CROSS_ANSWERS" \
    --hostcc=/usr/bin/cc \
    --disable-symbol-versions \
    --prefix="$PREFIX/samba-min" \
    --disable-python \
    --disable-warnings-as-errors \
    --without-ad-dc \
    --without-ads \
    --without-ldap \
    --without-winbind \
    --disable-cups \
    --without-pam \
    --without-systemd \
    --without-libunwind \
    --without-json \
    --without-quotas \
    --without-acl-support \
    --with-static-modules=catia,fruit,streams_xattr \
    --with-shared-modules='!DEFAULT' \
    --nonshared-binary=smbd/smbd

PYTHONHASHSEED=1 WAF_MAKE=1 ./buildtools/bin/waf build -j "${JOBS:-2}"
PYTHONHASHSEED=1 WAF_MAKE=1 ./buildtools/bin/waf install

for binary in smbd:sbin smbpasswd:bin testparm:bin; do
    name=${binary%%:*}
    directory=${binary#*:}
    test -x "$PREFIX/samba-min/$directory/$name" || {
        echo "Build completed without staged $name" >&2
        exit 1
    }
done

{
    echo "samba_version=$SAMBA_VERSION"
    echo "build_host=$(uname -srm)"
    echo "target=$TRIPLE"
    echo "target_os=NetBSD 6.0"
    echo "sysroot=$SYSROOT"
    echo "configure_flags=file-server-only,hostcc,no-symbol-versions,no-werror,without-libunwind,without-json,static-catia-fruit-streams_xattr"
} > "$PREFIX/BUILD-METADATA"

echo "Staged Samba $SAMBA_VERSION in $PREFIX"
