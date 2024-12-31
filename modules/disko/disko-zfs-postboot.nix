# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ pkgs, ... }:
let
  zfsPostBoot = pkgs.writeShellApplication {
    name = "zfsPostBootScript";
    runtimeInputs = with pkgs; [
      zfs
      gnugrep
      gawk
      cryptsetup
      util-linux
      gptfdisk
      parted
      systemd
    ];
    text = ''
      set -xeuo pipefail

      # Check which physical disk is used by ZFS
      ENCRYPTED_POOLNAME=zfs_data
      zpool import -f "$ENCRYPTED_POOLNAME"
      ZFS_POOLNAME=$(zpool list | grep -v NAME | grep $ENCRYPTED_POOLNAME | awk '{print $1}')
      ZFS_LOCATION=$(zpool status "$ZFS_POOLNAME" -P | grep dev | awk '{print $1}')

      # Get the actual device path
      P_DEVPATH=$(readlink -f "$ZFS_LOCATION")

      if [[ "$P_DEVPATH" =~ [0-9]+$ ]]; then
        PARTNUM=$(echo "$P_DEVPATH" | grep -o '[0-9]*$')
        PARENT_DISK=/dev/$(lsblk -no pkname "$P_DEVPATH")
      else
        echo "No partition number found in device path: $P_DEVPATH"
      fi

      set +o pipefail
      # Check if zfs pool has luks headers
      if (cryptsetup status "$ZFS_POOLNAME") | grep -q "is inactive"; then
        # Fix GPT first
        sgdisk "$PARENT_DISK" -e

        # Call partprobe to update kernel's partitions
        partprobe

        # Extend the partition to use unallocated space
        parted -s -a opt "$PARENT_DISK" "resizepart $PARTNUM 100%"

        # Extend ZFS pool to use newly allocated space
        zpool online -e "$ZFS_POOLNAME" "$ZFS_LOCATION"

        # Exporting pool to avoid device in use errors
        zpool export "$ZFS_POOLNAME"

        # TODO: Remove hardcoded password and have better password mechanism
        pswd="ghaf"
        # Format pool with LUKS
        echo -n $pswd | cryptsetup luksFormat --type luks2 -q "$ZFS_LOCATION"
        echo -n $pswd | cryptsetup luksOpen "$ZFS_LOCATION" "$ZFS_POOLNAME" --persistent

        # Enrolling for disk unlocking, it automatically assigns keys to a specific slot in the TPM
        PASSWORD=$pswd systemd-cryptenroll --tpm2-device auto "$P_DEVPATH"

        # Create pool, datasets as luksFormat will erase pools, ZFS datasets stored on that partition
        zpool create -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa -f "$ZFS_POOLNAME" /dev/mapper/"$ZFS_POOLNAME"
        zfs create -o quota=30G "$ZFS_POOLNAME"/vm_storage
        zfs create -o quota=10G -o mountpoint=none "$ZFS_POOLNAME"/reserved
        zfs create -o quota=50G "$ZFS_POOLNAME"/gp_storage
        zfs create "$ZFS_POOLNAME"/storagevm
        zfs create -o mountpoint=none "$ZFS_POOLNAME"/recovery
      fi
    '';
  };

in
{
  # To debug postBootCommands, one may run
  # journalctl -u initrd-nixos-activation.service
  # inside the running Ghaf host.
  boot.postBootCommands = "${zfsPostBoot}/bin/zfsPostBootScript";
}
