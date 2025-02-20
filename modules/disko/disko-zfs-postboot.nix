# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ pkgs, ... }:
let
  postBootCmds = ''
    set -xeuo pipefail

    # Check which physical disk is used by ZFS
    ZFS_POOLNAME=$(${pkgs.zfs}/bin/zpool list | ${pkgs.gnugrep}/bin/grep -v NAME |  ${pkgs.gawk}/bin/awk '{print $1}')
    ZFS_LOCATION=$(${pkgs.zfs}/bin/zpool status -P | ${pkgs.gnugrep}/bin/grep dev | ${pkgs.gawk}/bin/awk '{print $1}')

    # Get the actual device path
    P_DEVPATH=$(readlink -f "$ZFS_LOCATION")

    # Extract the partition number using regex
    if [[ "$P_DEVPATH" =~ [0-9]+$ ]]; then
      PARTNUM=$(echo "$P_DEVPATH" | ${pkgs.gnugrep}/bin/grep -o '[0-9]*$')
      PARENT_DISK=/dev/$(${pkgs.util-linux}/bin/lsblk -no pkname "$P_DEVPATH")
    else
      echo "No partition number found in device path: $P_DEVPATH"
    fi

    # Fix GPT first
    ${pkgs.gptfdisk}/bin/sgdisk "$PARENT_DISK" -e

    # Call partprobe to update kernel's partitions
    ${pkgs.parted}/bin/partprobe

    # Extend the partition to use unallocated space
    ${pkgs.parted}/bin/parted -s -a opt "$PARENT_DISK" "resizepart $PARTNUM 100%"

    # Extend ZFS pool to use newly allocated space
    ${pkgs.zfs}/bin/zpool online -e "$ZFS_POOLNAME" "$ZFS_LOCATION"
  '';
in
{
  # To debug postBootCommands, one may run
  # journalctl -u initrd-nixos-activation.service
  # inside the running Ghaf host.
  boot.postBootCommands = postBootCmds;

  # Test fscrypt encryption functionality
  systemd.services.testFscrypt = {
    description = "Test fscrypt service";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set +x
      ${pkgs.coreutils}/bin/chown $(id -u):$(id -g) /testfscrypt
      ${pkgs.fscrypt-experimental}/bin/fscrypt setup --force
      ${pkgs.fscrypt-experimental}/bin/fscrypt setup --force /testfscrypt
      ${pkgs.e2fsprogs}/bin/tune2fs -O encrypt "/dev/sda4"
      mkdir /testfscrypt/data
      echo -n "ghaf" | ${pkgs.fscrypt-experimental}/bin/fscrypt encrypt /testfscrypt/data/ --source=custom_passphrase
      date > /testfscrypt/data/hello.txt
      ls /testfscrypt/data
      ${pkgs.fscrypt-experimental}/bin/fscrypt lock /testfscrypt/data/
      ls /testfscrypt/data
      echo -n "ghaf" | ${pkgs.fscrypt-experimental}/bin/fscrypt unlock /testfscrypt/data/
      ${pkgs.fscrypt-experimental}/bin/fscrypt status

      # Clean up
      ${pkgs.fscrypt-experimental}/bin/fscrypt metadata destroy /testfscrypt --force
      rm -rf /testfscrypt/data /.fscrypt /etc/fscrypt.conf
      ${pkgs.fscrypt-experimental}/bin/fscrypt status
    '';
  };
}
