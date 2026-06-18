#!/bin/sh
set -u

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

echo '== system =='
uname -a
sysctl hw.machine hw.model hw.physmem 2>&1 || true

echo '== mounts and capacity =='
mount
df -k /Volumes/dk2 /Volumes/dk2/ShareRoot /mnt/Flash 2>&1 || true

echo '== interfaces and listeners =='
ifconfig -a
netstat -an 2>&1 | grep -E '[.:](22|139|445|1445)[[:space:]]' || true

echo '== packet filter =='
pfctl -s info 2>&1 || true
pfctl -sr 2>&1 || true
pfctl -sn 2>&1 || true

echo '== required tools =='
for tool in tar gzip cksum pfctl ifconfig netstat id ps readlink; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "$tool=$(command -v "$tool")"
    else
        echo "$tool=MISSING"
    fi
done

echo '== startup candidates =='
for path in /etc/rc.local /etc/rc.d /mnt/Flash /etc/pf.conf; do
    if test -e "$path"; then
        ls -ld "$path"
    fi
done

echo '== existing samba state =='
ps aux 2>&1 | grep '[s]mbd' || true
test -e /Volumes/dk2/.samba/current && ls -ld /Volumes/dk2/.samba/current || true
