{
  stdenv,
  pkgs,
  lib,
}: {
  src,
  modDirVersion,
  version,
  kernelPatches ? [],
}: let
  kernel =
    (pkgs.linuxManualConfig rec
      {
        inherit src modDirVersion version kernelPatches;
        inherit lib stdenv;
        allowImportFromDerivation = true;
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
      })
    .overrideAttrs (_old: {
      source = ./.;
      postUnpack = ''
        mkdir $dev
         cp $sourceRoot/scripts/kconfig/merge_config.sh $dev;
      '';

      postConfigure = ''
        $dev/merge_config.sh  -O $buildRoot $buildRoot/.config $source/virtualization.config ;
      '';
    });
in
  kernel
