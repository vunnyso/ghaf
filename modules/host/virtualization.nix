# Copyright 2023-2024 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  config,
  ...
}: let
  cfg = config.ghaf.host.virtualization_hardening;
in {
  options.ghaf.host.virtualization_hardening.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable virtualization support for ghaf host on Lenovo X1
    '';
  };
  config = lib.mkIf cfg.enable {
    boot.kernelPatches = [
      {
        name = "Virtualization support for ghaf host";
        patch = null;
        extraStructuredConfig = with lib.kernel; {
          VFIO = yes;
          VFIO_PCI = yes;
          IKCONFIG = yes;
          IKCONFIG_PROC = yes;
          POSIX_TIMERS = yes;
          BASE_FULL = yes;
        };
      }
    ];
  };
}
