# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Importing kernel builder function from packages and checking hardening options
  buildKernel = import ../../../../../packages/kernel {inherit config pkgs lib;};
  hardened_baseline = ../configs/ghaf_host_hardened_baseline-x86;
  host_hardened_kernel = buildKernel {config_baseline = hardened_baseline;};

  enable_kernel_baseline = config.ghaf.host.kernel.baseline_hardening.enable;
in
  with lib; {
    options.ghaf.host.hardening.enable = lib.mkOption {
      description = "Host hardening";
      type = lib.types.bool;
      default = false;
    };

    options.ghaf.host.kernel.baseline_hardening.enable = mkOption {
      description = "Host kernel hardening";
      type = types.bool;
      default = false;
    };

    options.ghaf.host.kernel.virtualization_hardening.enable = lib.mkOption {
      description = "Virtualization hardening for Ghaf Host";
      type = types.bool;
      default = false;
    };

    options.ghaf.host.kernel.networking_hardening.enable = mkOption {
      description = "Networking hardening for Ghaf Host";
      type = types.bool;
      default = false;
    };

    options.ghaf.host.kernel.usb_hardening.enable = mkOption {
      description = "USB hardening for Ghaf Host";
      type = types.bool;
      default = false;
    };

    options.ghaf.host.kernel.inputdevices_hardening.enable = mkOption {
      description = "User input devices hardening for Ghaf Host";
      type = types.bool;
      default = false;
    };

    options.ghaf.host.kernel.debug_hardening.enable = mkOption {
      description = "Debug hardening for Ghaf Host";
      type = types.bool;
      default = false;
    };

    config = mkIf enable_kernel_baseline {
      boot.kernelPackages = pkgs.linuxPackagesFor host_hardened_kernel;
      # https://github.com/NixOS/nixpkgs/issues/109280#issuecomment-973636212
      nixpkgs.overlays = [
        (_final: prev: {
          makeModulesClosure = x:
            prev.makeModulesClosure (x // {allowMissing = true;});
        })
      ];
    };
  }
