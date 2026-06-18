#!/bin/sh
set -u

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

echo '== system =='
uname -a
sysctl hw.machine hw.model hw.physmem 2>&1 || true

echo '== mounts and capacity =='
mount
echo '-- /Volumes --'
ls -la /Volumes 2>&1 || true
df -k /Volumes/dk2 /Volumes/dk2/ShareRoot /mnt/Flash 2>&1 || true

echo '== interfaces and listeners =='
ifconfig -a
netstat -an 2>&1

echo '== packet filter =='
pfctl -s info 2>&1 || true
pfctl -sr 2>&1 || true
pfctl -sn 2>&1 || true

echo '== required tools =='
for tool in cat cp df gzip ifconfig kill ln ls mkdir mount mv netstat pfctl ps rm scp sleep tar; do
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
ps aux 2>&1 || true
test -e /Volumes/dk2/.samba/current && ls -ld /Volumes/dk2/.samba/current || true
