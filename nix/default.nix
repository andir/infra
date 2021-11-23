{ system ? builtins.currentSystem
, config ? import ./config.nix
, patches ? [ ./patches/matrix-synpase-1.47.1.patch ]
}:
let
  patchedNixpkgs =
    let
      bootPkgs = import sources.nixpkgs { inherit system overlays config; };
    in
    source: patches: if patches == [ ] then source else
    bootPkgs.applyPatches {
      name = "nixpkgs-patched";
      inherit patches;
      src = source;
    };

  sources = import ./sources.nix;
  overlays = import ./overlays.nix { inherit system config; };
in
import (patchedNixpkgs sources.nixpkgs patches) { inherit system overlays config; }
