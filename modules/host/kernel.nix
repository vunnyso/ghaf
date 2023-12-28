# Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}: let
  #virt_patch = import ./virtualization.nix;
  baseKernel =
    if hyp_cfg.enable
    then
      pkgs.linux_6_1.override {
        argsOverride = rec {
          src = pkgs.fetchurl {
            url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
            hash = "sha256-qH4kHsFdU0UsTv4hlxOjdp2IzENrW5jPbvsmLEr/FcA=";
          };
          version = "6.1.55";
          modDirVersion = "6.1.55";
        };
      }
    else pkgs.linux_latest;
  hardened_kernel = pkgs.linuxManualConfig rec {
    inherit (baseKernel) src modDirVersion;
    version = "${baseKernel.version}-ghaf-hardened";
    /*
    baseline "make tinyconfig"
    - enabled for 64-bit, TTY, printk and initrd
    - fixed following NixOS required assertions via "make menuconfig" + search
    (following is documented here to highlight NixOS required (asserted) kernel features)
    ❯ nix build .#packages.x86_64-linux.lenovo-x1-carbon-gen11-debug --accept-flake-config
    error:
       Failed assertions:
       - CONFIG_DEVTMPFS is not enabled!
       - CONFIG_CGROUPS is not enabled!
       - CONFIG_INOTIFY_USER is not enabled!
       - CONFIG_SIGNALFD is not enabled!
       - CONFIG_TIMERFD is not enabled!
       - CONFIG_EPOLL is not enabled!
       - CONFIG_NET is not enabled!
       - CONFIG_SYSFS is not enabled!
       - CONFIG_PROC_FS is not enabled!
       - CONFIG_FHANDLE is not enabled!
       - CONFIG_CRYPTO_USER_API_HASH is not enabled!
       - CONFIG_CRYPTO_HMAC is not enabled!
       - CONFIG_CRYPTO_SHA256 is not enabled!
       - CONFIG_DMIID is not enabled!
       - CONFIG_AUTOFS4_FS is not enabled!
       - CONFIG_TMPFS_POSIX_ACL is not enabled!
       - CONFIG_TMPFS_XATTR is not enabled!
       - CONFIG_SECCOMP is not enabled!
       - CONFIG_TMPFS is not yes!
       - CONFIG_BLK_DEV_INITRD is not yes!
       - CONFIG_EFI_STUB is not yes!
       - CONFIG_MODULES is not yes!
       - CONFIG_BINFMT_ELF is not yes!
       - CONFIG_UNIX is not enabled!
       - CONFIG_INOTIFY_USER is not yes!
       - CONFIG_NET is not yes!
    ...
    additional NixOS dependencies (fixed):
    > modprobe: FATAL: Module uas not found ...
    > modprobe: FATAL: Module nvme not found ...
    ... < many packages enabled as M,
          others allowMissing = true with overlay
          - see implementation below under cfg.enable
    - also see https://github.com/NixOS/nixpkgs/issues/109280
      for the context >
    */

    configfile = ./ghaf_host_hardened_baseline;
    allowImportFromDerivation = true;
    # Experiment 2
    #Based on https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/manual-config.nix#L32
    kernelPatches = [
      {
        name = "enable-virt";
        patch = null;
        extraConfig = ''
          HIGH_RES_TIMERS y
          POSIX_TIMERS  y
          PRINTK  y
          BASE_FULL y
          IKCONFIG y;
          IKCONFIG_PROC  y;
        '';
      }
    ];
  };

  pkvm_patch = lib.mkIf config.ghaf.hardware.x86_64.common.enable [
    {
      name = "pkvm-patch";
    #  patch = ../virtualization/pkvm/0001-pkvm-enable-pkvm-on-intel-x86-6.1-lts.patch;
        patch = null;
      structuredExtraConfig = with lib.kernel; {
        KVM_INTEL = yes;
        KSM = no;
        PKVM_INTEL = yes;
        PKVM_INTEL_DEBUG = yes;
        PKVM_GUEST = yes;
        EARLY_PRINTK_USB_XDBC = yes;
        RETPOLINE = yes;
      };
    }
  ];

  kern_cfg = config.ghaf.host.kernel_hardening;
  hyp_cfg = config.ghaf.host.hypervisor_hardening;

  overlay1 = _final: prev: {
    makeModulesClosure = x:
      prev.makeModulesClosure (x // {allowMissing = true;});
  };
  overlay2 = _final: prev: {
    hardened_kernel = prev.hardened_kernel.extend (lib.const (kprev: {
      kernel = kprev.kernel.override {
        extraConfig = ''
          I2C y
        '';
      };
    }));
  };
# below statement also not working
 hardened_kernel.boot.kernelPatches = pkvm_patch;

in
  with lib; {
    options.ghaf.host.kernel_hardening = {
      enable = mkEnableOption "Host kernel hardening";
    };

    options.ghaf.host.hypervisor_hardening = {
      enable = mkEnableOption "Hypervisor hardening";
    };



    config = mkIf kern_cfg.enable {
      boot.kernelPackages = pkgs.linuxPackagesFor hardened_kernel;
      boot.kernelPatches = mkIf (hyp_cfg.enable && "${baseKernel.version}" == "6.1.55") pkvm_patch;
      
      # https://github.com/NixOS/nixpkgs/issues/109280#issuecomment-973636212
      # Experiment 3, creating one more overlay source < https://discourse.nixos.org/t/the-correct-way-to-override-the-latest-kernel-config/533 >
      nixpkgs.overlays = [overlay1];
    };
  }
