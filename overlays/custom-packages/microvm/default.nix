# Copyright 2022-2025 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ prev }:
prev.microvm.overrideAttrs (
  _final: prev: {
    postInstall =
      (prev.postInstall or "")
      + ''
        sed -i "s/'\$(\([^)]*\))' /\"\$(\1)\" /g" "$out/microvm-run"
      '';
  }
)
