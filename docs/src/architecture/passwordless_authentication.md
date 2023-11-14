<!--
    Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
    SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Yubikey Passwordless Authentication

This section describes Ghaf reference implementation for passwordless authentication for fast identity online (FIDO). The reference implementation has been created with Yubico Yubikeys.
The implementation is modular and configurable - thus enabling also other implementations.

This section describes Yubikey Passwordless Authentication and how to create U2F keys.

The reader is expected to know the fundamentals of [FIDO](https://fidoalliance.org/specifications/), [Yubico](https://www.yubico.com/) and [U2F](https://developers.yubico.com/U2F/).

## Prerequisites for Yubikey Passwordless Authentication

User must have compatible [YubiKey hardware](https://www.yubico.com/products/) to begin with.

## Creating Yubikey U2F Keys

Yubikey U2F keys can be created with [pamu2fcfg](https://developers.yubico.com/pam-u2f/), a module implements PAM over U2F and FIDO2. pamu2fcfg is available in Nixpkgs as pkgs.pamu2fcfg.

Use the following command to create your U2F keys for Ghaf gui-vm .
```
$ pamu2fcfg -u ghaf -o pam://gui-vm | sudo tee /etc/u2f_mappings
```

After running above command, there will be green light blinking on Yubikey and user need to tap it.
Once executed successfully, now user authentication becomes passwordless. When prompted with password just tap Yubikey.

## Current Implementation

Since passwordless authentication is mapped with Yubikey in use and each Yubikey will generate unique key. So its not possible to use generic key.
Yubikey Passwordless Authentication feature is enabled in debug builds for ghaf host only.

### Yubikey Passwordless Authentication Verification
If system is not asking you password in ghaf host anymore then Yubikey Passwordless Authentication feature is working fine.
