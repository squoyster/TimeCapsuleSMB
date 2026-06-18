#!/bin/sh
set -eu

SAMBA_VERSION=4.24.3

: "${SAMBA_SOURCE:?Set SAMBA_SOURCE to the unpacked Samba ${SAMBA_VERSION} source directory}"
: "${TOOLDIR:?Set TOOLDIR to the NetBSD cross-tool directory}"
: "${SYSROOT:?Set SYSROOT to the NetBSD 6 evbarm DESTDIR/sysroot}"
: "${TRIPLE:?Set TRIPLE to the target compiler prefix, for example arm--netbsdelf-eabi}"
: "${PREFIX:?Set PREFIX to an empty staging directory}"
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
    "$CROSS_ANSWERS"
do
    test -e "$path" || { echo "Missing required build input: $path" >&2; exit 2; }
done

if test -d "$PREFIX" && test -n "$(ls -A "$PREFIX")"; then
    echo "PREFIX must be empty: $PREFIX" >&2
    exit 2
fi
mkdir -p "$PREFIX"

export PATH="$TOOLDIR/bin:$PATH"
export CC="$TOOLDIR/bin/$TRIPLE-gcc --sysroot=$SYSROOT"
export CXX="$TOOLDIR/bin/$TRIPLE-g++ --sysroot=$SYSROOT"
export AR="$TOOLDIR/bin/$TRIPLE-ar"
export RANLIB="$TOOLDIR/bin/$TRIPLE-ranlib"
export STRIP="$TOOLDIR/bin/$TRIPLE-strip"
export CFLAGS="${CFLAGS:--Os -fno-ident}"
export CPPFLAGS="${CPPFLAGS:--I$SYSROOT/usr/include -D_NETBSD_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES}"
export LDFLAGS="${LDFLAGS:---sysroot=$SYSROOT -L$SYSROOT/lib -L$SYSROOT/usr/lib}"
export PKG_CONFIG_DIR=
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:-$PREFIX/lib/pkgconfig}"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

cd "$SAMBA_SOURCE"
rm -rf bin .waf-* .lock-waf* config.log

./configure \
    --cross-compile \
    --cross-answers="$CROSS_ANSWERS" \
    --prefix="$PREFIX/samba-min" \
    --disable-python \
    --without-ad-dc \
    --without-ads \
    --without-ldap \
    --without-winbind \
    --disable-cups \
    --without-pam \
    --without-systemd \
    --without-quotas \
    --without-acl-support \
    --with-static-modules=catia,fruit,streams_xattr \
    --with-shared-modules='!DEFAULT' \
    --nonshared-binary=smbd/smbd

./buildtools/bin/waf build -j "${JOBS:-2}"
./buildtools/bin/waf install

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
    echo "target=$TRIPLE"
    echo "sysroot=$SYSROOT"
    echo "configure_flags=file-server-only,static-catia-fruit-streams_xattr"
} > "$PREFIX/BUILD-METADATA"

echo "Staged Samba $SAMBA_VERSION in $PREFIX"
