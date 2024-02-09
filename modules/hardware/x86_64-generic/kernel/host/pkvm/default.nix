# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}: let
  pkvmKernel = pkgs.linux_6_1.override {
    argsOverride = rec {
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
        hash = "sha256-qH4kHsFdU0UsTv4hlxOjdp2IzENrW5jPbvsmLEr/FcA=";
      };
      version = "6.1.55";
      modDirVersion = "6.1.55";
    };
  };

  pkvm_patch = [
    {
      name = "pkvm-patch";
      patch = ../../../../../virtualization/pkvm/0001-pkvm-enable-pkvm-on-intel-x86-6.1-lts.patch;
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

  hyp_cfg = config.ghaf.host.hypervisor_hardening;
in
  with lib; {
    options.ghaf.host.hypervisor_hardening.enable = mkOption {
      description = "Hypervisor hardening";
      type = types.bool;
      default = false;
    };
    config = mkIf hyp_cfg.enable {
      boot.kernelPackages = pkgs.linuxPackagesFor pkvmKernel;
      boot.kernelPatches = mkIf (hyp_cfg.enable && "${pkvmKernel.version}" == "6.1.55") pkvm_patch;
    };
  }
