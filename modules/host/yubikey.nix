# Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.ghaf.host.passwordless_authentication;
in {
  options.ghaf.host.passwordless_authentication = {
    enable = lib.mkEnableOption "Host Yubikeys Support";
  };

  config = lib.mkIf cfg.enable {
    environment.etc.u2f_mappings.source = ./demo-yubikeys/u2f_keys;
    environment.systemPackages = [
      # For generating and debugging Yubikeys
      pkgs.pam_u2f
      pkgs.usbutils
    ];

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
    };
    # If authFile is not present then there will be no error, system will work in usual way.
    # If authFile is present and Yubikey is connected then passwordless authenication works.
    security.pam.u2f.authFile = "/etc/u2f_mappings";
  };
}
