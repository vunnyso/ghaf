# Copyright 2022-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{config, ...}: {
  imports = [
    ../../../../x86_64-generic/kernel/host/default.nix
    ../../../../x86_64-generic/kernel/guest/default.nix
  ];

  # baseline, virtualization and network hardening are
  # generic to all x86_64 devices
  config.ghaf.host.kernel.baseline_hardening.enable = true;
  config.ghaf.host.kernel.virtualization_hardening.enable = true;
  config.ghaf.host.kernel.networking_hardening.enable = true;
  # usb hardening is host optional but required for -debug builds
  config.ghaf.host.kernel.usb_hardening.enable = true;

  # guest VM kernel specific options
  config.ghaf.guest.hardening.enable = true;
  config.ghaf.guest.graphics_hardening.enable = true;

  # required to module test a module via top level configuration
  config.boot.loader.systemd-boot.enable = true;
  config.fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };
  config.system.stateVersion = "23.11";
}
