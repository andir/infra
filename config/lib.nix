let
  sources = import ../nix/sources.nix;
  extraModules = (import sources.modules).all;
in
{
  # Inject my custom modules into the machine and set some common things.
  mkMachine = { name, config, system ? "x86_64-linux" }:
    {
      imports = [
        config
        (
          { lib, config, ... }:
          {
            nixpkgs = {
              pkgs = lib.mkDefault (import ../nix/nixpkgs-for-machine.nix {
                inherit system name;
              });
              inherit system;
            };
          }
        )
        ./servers/wireguard.nix
      ] ++ extraModules;
    };
}
