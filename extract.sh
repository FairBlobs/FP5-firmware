#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-factory-image.zip>"
    exit 1
fi

tmpdir=$(mktemp -d)
mount=$(mktemp -d)

cleanup() {
    set +e
    sudo umount "$mount"

    sudo dmsetup remove /dev/mapper/dynpart-*
    sudo losetup -d "$loopdev"

    sudo rmdir "$mount"
    sudo rm -r "$tmpdir"
}
trap cleanup EXIT

unzip -d "$tmpdir" "$1" images/BTFM.bin images/dspso.bin images/NON-HLOS.bin images/super.img

mkdir hexagonfs hexagonfs/dsp hexagonfs/sensors

### NON-HLOS.bin ###
sudo mount -o ro "$tmpdir"/images/NON-HLOS.bin "$mount"
cp "$mount"/image/adsp* .
cp "$mount"/image/battmgr.jsn .
cp "$mount"/image/cdsp* .
cp -r "$mount"/image/modem* .
cp "$mount"/image/wpss* .
sudo umount "$mount"

### BTFM.bin ###
sudo mount -o ro "$tmpdir"/images/BTFM.bin "$mount"
cp "$mount"/image/msbtfw11.mbn .
cp "$mount"/image/msnv11.bin .
sudo umount "$mount"

### dspso.bin ###
sudo mount -o ro "$tmpdir"/images/dspso.bin "$mount"
cp -r "$mount"/*dsp hexagonfs/dsp/
sudo umount "$mount"

### super.img ###
simg2img "$tmpdir"/images/super.img "$tmpdir"/super.raw.img
rm "$tmpdir"/images/super.img

loopdev=$(sudo losetup --read-only --find --show "$tmpdir"/super.raw.img)
sudo dmsetup create --concise "$(sudo parse-android-dynparts "$loopdev")"

sudo mount -o ro /dev/mapper/dynpart-vendor_a "$mount"
cp "$mount"/firmware/a660_zap.b* .
cp "$mount"/firmware/a660_zap.mdt .
cp "$mount"/firmware/yupik_ipa_fws.* .
cp "$mount"/firmware/vpu20_1v.mbn .
cp -r "$mount"/etc/acdbdata hexagonfs/acdb
cp -r "$mount"/etc/sensors/config hexagonfs/sensors/config
cp -r "$mount"/etc/sensors/sns_reg_config hexagonfs/sensors/sns_reg.conf

# Sensor registry for hexagonfs is extracted from persist partition which is
# not shipped with the factory image.
# cp -r /mnt/persist/sensors/registry/registry hexagonfs/sensors/registry

# Socinfo files are extracted from the running device with stock Android.
# for i in hw_platform platform_subtype platform_subtype_id platform_version revision soc_id; do adb shell cat /sys/devices/soc0/$i > hexagonfs/socinfo/$i; done

# cleanup happens on exit with the signal handler at the top
