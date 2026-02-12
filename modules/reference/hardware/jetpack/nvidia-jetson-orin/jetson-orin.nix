# SPDX-FileCopyrightText: 2022-2026 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# Configuration for NVIDIA Jetson Orin AGX/NX reference boards
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.ghaf.hardware.nvidia.orin;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;
  resizepartitionsScript = pkgs.writeShellApplication {
    name = "resize-partitions-cmds";
    runtimeInputs = with pkgs; [
      gptfdisk
      parted
      cryptsetup
      util-linux
      e2fsprogs
      coreutils
      systemd
    ];
    text = ''
      set -x
      DISK="/dev/mmcblk0"
      PART_NUM=1
      PART_DEV="/dev/mmcblk0p1"

      RESIZE_TARGET="$PART_DEV"
      ${lib.optionalString cfg.diskEncryption.enable ''
        MAPPER_NAME="${cfg.diskEncryption.mapperName}"
        RESIZE_TARGET="/dev/mapper/$MAPPER_NAME"
      ''}

      # Wait for the device to be available
      for _ in {1..30}; do
        [ -b "$RESIZE_TARGET" ] && break
        sleep 1
      done

      if [ ! -b "$RESIZE_TARGET" ]; then
        echo "Target device $RESIZE_TARGET not found, skipping."
        exit 0
      fi

      # Check for marker file by mounting temporarily
      mkdir -p /mnt-resize
      if mount "$RESIZE_TARGET" /mnt-resize; then
        if [ -f /mnt-resize/var/lib/ghaf-resize-done ]; then
          echo "Resize already performed, skipping."
          umount /mnt-resize
          exit 0
        fi
        umount /mnt-resize
      fi

      echo "Fixing GPT..."
      sgdisk -e "$DISK" || true

      echo "Resizing partition $PART_NUM to 100%..."
      # Use resizepart which works on busy partitions by using the BLKPG_RESIZE_PARTITION ioctl
      parted -s "$DISK" resizepart "$PART_NUM" 100%

      # Re-read partition table and wait for udev
      partprobe "$DISK" || true
      udevadm settle || true

      ${lib.optionalString cfg.diskEncryption.enable ''
        echo "Resizing LUKS container $MAPPER_NAME..."
        # Try resizing without passphrase first
        if ! cryptsetup resize -v "$MAPPER_NAME"; then
          echo "LUKS resize needs authentication..."
          # Use systemd-ask-password to handle prompts in a non-interactive environment
          PASSPHRASE=$(systemd-ask-password --timeout=60 "Enter passphrase for resizing LUKS container:")
          if [ -n "$PASSPHRASE" ]; then
            echo "$PASSPHRASE" | cryptsetup resize -v "$MAPPER_NAME" --key-file=-
          else
             echo "No passphrase entered, LUKS resize might have failed."
          fi
        fi
        echo "LUKS status for $MAPPER_NAME after resize:"
        cryptsetup status "$MAPPER_NAME"
      ''}

      echo "Resizing filesystem on $RESIZE_TARGET..."
      # resize2fs may require a filesystem check before resizing
      e2fsck -fy "$RESIZE_TARGET" || true
      resize2fs "$RESIZE_TARGET"

      # Create marker file
      if mount "$RESIZE_TARGET" /mnt-resize; then
        mkdir -p /mnt-resize/var/lib
        touch /mnt-resize/var/lib/ghaf-resize-done
        umount /mnt-resize
      fi
    '';
  };

in
{
  options.ghaf.hardware.nvidia.orin = {
    # Enable the Orin boards
    enable = mkEnableOption "Orin hardware";

    flashScriptOverrides.onlyQSPI = mkEnableOption "to only flash QSPI partitions, i.e. disable flashing of boot and root partitions to eMMC";

    flashScriptOverrides.preFlashCommands = mkOption {
      description = "Commands to run before the actual flashing";
      type = types.str;
      default = "";
    };

    somType = mkOption {
      description = "SoM config Type (NX|AGX32|AGX64|Nano)";
      type = types.str;
      default = "agx";
    };

    carrierBoard = mkOption {
      description = "Board Type";
      type = types.str;
      default = "devkit";
    };

    kernelVersion = mkOption {
      description = "Kernel version";
      type = types.str;
      default = "bsp-default";
    };

    diskEncryption = {
      enable = mkEnableOption "generic LUKS root filesystem encryption for eMMC APP partition";

      mode = mkOption {
        description = "Disk encryption mode for Jetson root filesystem";
        type = types.enum [ "generic-luks-passphrase" ];
        default = "generic-luks-passphrase";
      };

      mapperName = mkOption {
        description = "Mapped device name used by initrd after LUKS unlock";
        type = types.str;
        default = "cryptroot";
      };
    };
  };

  config = mkIf cfg.enable {
    hardware.nvidia-jetpack.kernel.version = "${cfg.kernelVersion}";
    nixpkgs.hostPlatform.system = "aarch64-linux";

    environment.systemPackages = with pkgs; [
      gptfdisk
      parted
      cryptsetup
      util-linux
      e2fsprogs
    ];

    ghaf.hardware.aarch64.systemd-boot-dtb.enable = true;

    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };

      modprobeConfig.enable = true;

      kernelPatches = [
        {
          name = "vsock-config";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            VHOST = yes;
            VHOST_MENU = yes;
            VHOST_IOTLB = yes;
            VHOST_VSOCK = yes;
            VSOCKETS = yes;
            VSOCKETS_DIAG = yes;
            VSOCKETS_LOOPBACK = yes;
            VIRTIO_VSOCKETS_COMMON = yes;
          };
        }
      ]
      ++ lib.optionals (cfg.diskEncryption.enable && cfg.kernelVersion == "upstream-6-6") [
        {
          name = "dm-crypt-config";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            BLK_DEV_DM = yes;
            DM_BUFIO = yes;
            DM_BIO_PRISON = yes;
            DM_CRYPT = yes;
            CRYPTO_USER_API = yes;
            CRYPTO_USER_API_HASH = yes;
            CRYPTO_USER_API_SKCIPHER = yes;
            CRYPTO_XTS = yes;
          };
        }
      ];

    };

    boot.initrd = {
      # Keep module selection aligned with the Orin JetPack baseline and avoid
      # requesting dm-crypt as a loadable module for upstream-6-6.
      availableKernelModules = [
        "xhci-tegra"
        "ucsi_ccg"
        "typec_ucsi"
        "typec"
        "nvme"
        "tegra_mce"
        "phy-tegra-xusb"
        "i2c-tegra"
        "fusb301"
        "phy_tegra194_p2u"
        "pcie_tegra194"
        "nvpps"
        "nvethernet"
      ]
      ++ lib.optionals cfg.diskEncryption.enable [
        "dm-crypt"
        "dm-mod"
      ];
      kernelModules = [ ];
      # algif_skcipher is not available with the upstream-6-6 kernel variant
      # used by current Orin reference targets.
      luks.cryptoModules = lib.mkIf cfg.diskEncryption.enable (
        lib.mkForce [
          "aes"
          "aes_generic"
          "cbc"
          "xts"
          "sha1"
          "sha256"
          "sha512"
          "af_alg"
        ]
      );
      luks.devices = lib.mkIf cfg.diskEncryption.enable {
        ${cfg.diskEncryption.mapperName} = {
          device = "/dev/mmcblk0p1";
          allowDiscards = true;
        };
      };

      systemd.storePaths = with pkgs; [
        gptfdisk
        parted
        cryptsetup
        util-linux
        e2fsprogs
        coreutils
        systemd
        resizepartitionsScript
      ];

      systemd.services.resize-partitions = {
        description = "Resize partitions to fill the disk on first boot";
        wantedBy = [ "initrd.target" ];
        before = [
          "sysroot.mount"
          "initrd-root-fs.target"
        ];
        after = [ "cryptsetup.target" ];
        unitConfig = {
          DefaultDependencies = false;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${resizepartitionsScript}/bin/resize-partitions-cmds";
          StandardInput = "tty";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
      };

      supportedFilesystems = [ "ext4" ];
    };

    fileSystems = mkIf cfg.diskEncryption.enable {
      "/" = lib.mkForce {
        device = "/dev/mapper/${cfg.diskEncryption.mapperName}";
        fsType = "ext4";
      };
    };

    ghaf.hardware.passthrough.vhotplug.enable = true;
    ghaf.hardware.passthrough.usbQuirks.enable = true;

    services.nvpmodel = {
      enable = lib.mkDefault true;
      # Enable all CPU cores, full power consumption (50W on AGX, 25W on NX)
      profileNumber = lib.mkDefault 3;
    };
    hardware.deviceTree = {
      enable = lib.mkDefault true;
      # Add the include paths to build the dtb overlays
      dtboBuildExtraIncludePaths = [
        "${lib.getDev config.hardware.deviceTree.kernelPackage}/lib/modules/${config.hardware.deviceTree.kernelPackage.modDirVersion}/source/nvidia/soc/t23x/kernel-include"
      ];
    };

    # NOTE: "-nv.dtb" files are from NVIDIA's BSP
    # Versions of the device tree without PCI passthrough related
    # modifications.
  };
}
