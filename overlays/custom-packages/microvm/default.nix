# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
#
# This overlay intend to customize microvm
#
{ inputs }:
(_final: prev: {
  # Without inputs also overlay cannot be applied to microvm
  inputs.microvm = prev.microvm.overrideAttrs (_oldAttrs: {
    postInstall = ''
      echo "Custom postInstall script"
      This should throw error but compilation is sucessful 
    '';
  });
})
