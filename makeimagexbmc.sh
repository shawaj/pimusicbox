#!/bin/bash
if [ $(id -u) != "0" ]; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

MB_DIRECTORY='/home/wouter/mb_data'
DRIVE='/dev/sdb'
PART1=$DRIVE'1'
PART2=$DRIVE'2'

umount $PART1
umount $PART2

echo "Version:"
read IMGVERSION

ZIPNAME='mediabox'$IMGVERSION'.zip'
IMGNAME='mediabox'$IMGVERSION'.img'

rm $MB_DIRECTORY'/'$ZIPNAME
rm $MB_DIRECTORY'/'$IMGNAME
rm /media/sf_Downloads/$ZIPNAME
rm /media/sf_Downloads/$IMGNAME

echo "Zero root (y/N)?"
read ZEROROOT

echo "Resize size to 1912 MB(y/N)?"
read RESIZEFS

if [ "$RESIZEFS" == "y" ]
then
    echo "Check..."
    e2fsck -fy $PART2
    echo "Resize to 1912MB..."
    resize2fs $PART2 1912M
    echo "Ready"

  # Get the starting offset of the root partition
  PART_START=$(parted $DRIVE -ms unit s p | grep "^2" | cut -f 2 -d: | tr -cd "[:digit:]")
  [ "$PART_START" ] || exit 1
  # Return value will likely be error for fdisk as it fails to reload the 
  # partition table because the root fs is mounted
  fdisk $DRIVE <<EOF
p
d
2
n
p
2
$PART_START
+1915M
p
w
EOF

#wait
    echo "Ok?"
    read TMPINPUT
fi

MNT='/mnt/tmp'$IMGVERSION
MNT2='/mnt/tmp'$IMGVERSION'2'

cd $MB_DIRECTORY

mkdir $MNT
mkdir $MNT2
mount $PART1 $MNT
cp -r $MNT/config /tmp
rm -r $MNT/config
cp -r config $MNT
rm -r $MNT/config/.*

#xbmc backup
cp -r $MNT2/home/musicbox/.xbmc /tmp

#(apple) hidden stuff
rm -r $MNT/.*
rm -r $MNT/config/.*

echo "Zero FAT"
dd if=/dev/zero of=$MNT/zero bs=1M
rm $MNT/zero

mount $PART2 $MNT2

#remove network settings, etc
rm $MNT2/var/lib/dhcp/*.leases
touch $MNT2/var/lib/dhcp/dhcpd.leases
rm $MNT2/var/lib/alsa/*
rm $MNT2/var/lib/dbus/*
rm $MNT2/var/lib/avahi-autoipd/*
rm $MNT2/etc/udev/rules.d/*.rules
#logs
rm -r $MNT2/var/log/*
rm -r $MNT2/var/log/apt/*

#remove spotify/audio settings
rm -r $MNT2/home/musicbox/.cache/gmusicapi/*
rm -r $MNT2/home/musicbox/.cache/mopidy/*
rm -r $MNT2/home/musicbox/.gstreamer-0.10/*
rm -r $MNT2/home/musicbox/.xbmc
rm -r $MNT2/tmp/*

cp -r .xbmc $MNT2/home/musicbox
chown -R wouter:wouter $MNT2/home/musicbox/.xbmc

#put version in login prompt
echo -e 'MediaBox '$IMGVERSION"\n" > $MNT2/etc/issue

#music
rm -r $MNT2/music/local/*

#bash history
rm $MNT2/home/musicbox/.bash_history

#config
rm $MNT2/home/musicbox/.config/mopidy/*
rm $MNT2/home/musicbox/.config/mc

#root
rm $MNT2/root/*

#old stuff
rm -r $MNT2/boot.bk
rm -r $MNT2/lib/modules.bk

if [ "$ZEROROOT" = "Y" -o "$ZEROROOT" = "y" ]; then
    echo "Zero Root FS"
    dd if=/dev/zero of=$MNT2/zero bs=1M
    rm $MNT2/zero
fi

echo "wait 30 sec for mount"
sleep 30

umount $MNT
umount $MNT2

echo "Ok?"
read TST

umount $MNT
umount $MNT2

echo "DD 1920 * 1M"
dd bs=1M if=$DRIVE count=1920 | pv -s 1920m | dd of=mediabox$IMGVERSION.img

echo "Copy Config back"
mount $PART1 $MNT
mount $PART2 $MNT2
cp -r /tmp/config $MNT
rm -r /tmp/config
rm -r $MNT2/home/musicbox/.xbmc
cp -r /tmp/.xbmc $MNT2/home/musicbox
rm -r /tmp/.xbmc

chown -R wouter:wouter $MNT2/home/musicbox/.xbmc

echo "wait 30 sec for umount"
sleep 30
umount $MNT
umount $MNT2
rmdir $MNT
rmdir $MNT2

echo "zip image"
zip -9 $ZIPNAME $IMGNAME MusicBox_Manual.pdf

echo "copy zip"
cp $ZIPNAME /media/sf_Downloads
cp $IMGNAME /media/sf_Downloads

umount $MNT
umount $MNT2
rmdir $MNT
rmdir $MNT2

