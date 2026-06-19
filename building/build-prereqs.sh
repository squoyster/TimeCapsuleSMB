#!/bin/sh
set -eu

: "${TOOLDIR:?Set TOOLDIR to the NetBSD cross-tool directory}"
: "${SYSROOT:?Set SYSROOT to the NetBSD 6 evbarm DESTDIR/sysroot}"
: "${TRIPLE:?Set TRIPLE to the target compiler prefix, for example arm--netbsdelf-eabi}"
: "${PREFIX:?Set PREFIX to the staging directory shared with build-samba.sh}"

GMP_VERSION="${GMP_VERSION:-6.2.1}"
NETTLE_VERSION="${NETTLE_VERSION:-3.9.1}"
GNUTLS_VERSION="${GNUTLS_VERSION:-3.7.11}"
BUILD_ROOT="${BUILD_ROOT:-$HOME/tc-build}"
JOBS="${JOBS:-2}"

for path in \
    "$TOOLDIR/bin/$TRIPLE-gcc" \
    "$TOOLDIR/bin/$TRIPLE-g++" \
    "$TOOLDIR/bin/$TRIPLE-ar" \
    "$TOOLDIR/bin/$TRIPLE-ranlib"
do
    test -e "$path" || { echo "Missing required build input: $path" >&2; exit 2; }
done

mkdir -p "$PREFIX" "$BUILD_ROOT"

export PATH="$TOOLDIR/bin:/usr/pkg/bin:$PATH"
export CC="$TOOLDIR/bin/$TRIPLE-gcc --sysroot=$SYSROOT"
export CXX="$TOOLDIR/bin/$TRIPLE-g++ --sysroot=$SYSROOT"
export AR="$TOOLDIR/bin/$TRIPLE-ar"
export RANLIB="$TOOLDIR/bin/$TRIPLE-ranlib"
export STRIP="$TOOLDIR/bin/$TRIPLE-strip"
export CFLAGS="${CFLAGS:--Os -fno-ident}"
export CPPFLAGS="${CPPFLAGS:--I$PREFIX/include -I$SYSROOT/usr/include -D_NETBSD_SOURCE -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES}"
export LDFLAGS="${LDFLAGS:---sysroot=$SYSROOT -L$PREFIX/lib -L$SYSROOT/lib -L$SYSROOT/usr/lib}"
export PKG_CONFIG_DIR=
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${PKG_CONFIG_SYSROOT_DIR:-}"

need_native_tool() {
    tool="$1"
    package="$2"
    if command -v "$tool" >/dev/null 2>&1; then
        return 0
    fi
    echo "Missing required native tool: $tool" >&2
    echo "Install it in the VM first, for example: pkgin install $package" >&2
    exit 2
}

fetch() {
    url="$1"
    file="$2"
    if test -f "$file"; then
        return 0
    fi
    ftp -o "$file" "$url"
}

need_native_tool gmake pkgconf
need_native_tool pkg-config pkgconf
need_native_tool ftp tnftp
need_native_tool tar bsdtar

cd "$BUILD_ROOT"

fetch "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.xz" "gmp-$GMP_VERSION.tar.xz"
fetch "https://ftp.gnu.org/gnu/nettle/nettle-$NETTLE_VERSION.tar.gz" "nettle-$NETTLE_VERSION.tar.gz"
fetch "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-$GNUTLS_VERSION.tar.xz" "gnutls-$GNUTLS_VERSION.tar.xz"

test -d "gmp-$GMP_VERSION" || tar -xf "gmp-$GMP_VERSION.tar.xz"
test -d "nettle-$NETTLE_VERSION" || tar -xf "nettle-$NETTLE_VERSION.tar.gz"
test -d "gnutls-$GNUTLS_VERSION" || tar -xf "gnutls-$GNUTLS_VERSION.tar.xz"

cd "$BUILD_ROOT/gmp-$GMP_VERSION"
gmake distclean >/dev/null 2>&1 || true
./configure \
    --build="$(./config.guess)" \
    --host="$TRIPLE" \
    --prefix="$PREFIX" \
    --disable-nls \
    --enable-shared \
    --disable-static
gmake -j "$JOBS"
gmake install

cd "$BUILD_ROOT/nettle-$NETTLE_VERSION"
gmake distclean >/dev/null 2>&1 || true
CPPFLAGS="-I$PREFIX/include" \
LDFLAGS="-L$PREFIX/lib -L$SYSROOT/lib -L$SYSROOT/usr/lib" \
./configure \
    --build="$(sh config.guess)" \
    --host="$TRIPLE" \
    --prefix="$PREFIX" \
    --enable-shared \
    --disable-static \
    --disable-openssl \
    --disable-documentation
gmake -j "$JOBS"
env -u DESTDIR gmake install

cd "$BUILD_ROOT/gnutls-$GNUTLS_VERSION"
gmake distclean >/dev/null 2>&1 || true
CPPFLAGS="-I$PREFIX/include" \
LDFLAGS="-L$PREFIX/lib -L$SYSROOT/lib -L$SYSROOT/usr/lib" \
./configure \
    --build="$(sh build-aux/config.guess)" \
    --host="$TRIPLE" \
    --prefix="$PREFIX" \
    --with-included-libtasn1 \
    --with-included-unistring \
    --disable-doc \
    --disable-tools \
    --disable-tests \
    --disable-cxx \
    --disable-guile \
    --without-p11-kit
gmake -j "$JOBS"
env -u DESTDIR gmake install

cat > "$PREFIX/lib/pkgconfig/zlib.pc" <<EOF
prefix=$SYSROOT/usr
exec_prefix=\${prefix}
libdir=$SYSROOT/lib
includedir=$SYSROOT/usr/include

Name: zlib
Description: zlib compression library from the NetBSD base system
Version: 1.2.7
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF

GNUTLS_PC="$PREFIX/lib/pkgconfig/gnutls.pc"
if test -f "$GNUTLS_PC"; then
    perl -0pi -e 's/^Libs:.*$/Libs: -L${libdir} -lgnutls -lhogweed -lnettle -lgmp -lz/m' "$GNUTLS_PC"
    perl -0pi -e 's/^Libs\.private:.*$/Libs.private:/m' "$GNUTLS_PC"
    perl -0pi -e 's/^Requires\.private:.*$/Requires.private:/m' "$GNUTLS_PC"
fi

{
    echo "gmp_version=$GMP_VERSION"
    echo "nettle_version=$NETTLE_VERSION"
    echo "gnutls_version=$GNUTLS_VERSION"
} > "$PREFIX/PREREQ-METADATA"

echo "Staged GMP, nettle, and GnuTLS in $PREFIX"
