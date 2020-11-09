let
  extraModules = (import (import ../nix/sources.nix).modules).all;
in
{
  # Inject my custom modules into the machine and set some common things.
  mkMachine = { config, system ? "x86_64-linux" }:
    let
      definedSystem = system;
    in
    {
      imports = [
        config
        (
          { lib, config, ... }:
          {
            nixpkgs.pkgs = lib.mkDefault (import ../nix { system = definedSystem; });
            nixpkgs.system = definedSystem;
          }
        )
        ./servers/wireguard.nix
      ] ++ extraModules;
    };
}
