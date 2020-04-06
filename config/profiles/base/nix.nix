{ lib, ... }:
{
  nix = {
    autoOptimiseStore = lib.mkDefault true;
    gc = {
      automatic = lib.mkDefault true;
      options = lib.mkDefault "--delete-older-than 14d";
    };
    binaryCaches = [
      "https://cache.nixos.org"
      "https://cache.h4ck.space"
    ];

    binaryCachePublicKeys = [
      "zeta:9zm3cHRlqz3T9HnRsodtQGGqHOLDAiB+8d0kOKnFI0M="
    ];
  };
}
