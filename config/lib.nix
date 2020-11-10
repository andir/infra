let
  sources = import ../nix/sources.nix;
  extraModules = (import sources.modules).all;
in
{
  # Inject my custom modules into the machine and set some common things.
  mkMachine = { name, config, system ? "x86_64-linux" }:
    let
      definedSystem = system;
    in
    {
      imports = [
        config
        (
          { lib, config, ... }:
          let
            overlays = import ../nix/overlays.nix { system = definedSystem; };
            expr =
              if sources ? "${name}-nixpkgs" then
                import sources."${name}-nixpkgs"
                  {
                    system = definedSystem;
                    inherit overlays;
                  }
              else import ../nix { system = definedSystem; };
          in
          {
            nixpkgs.pkgs = lib.mkDefault expr;
            nixpkgs.system = definedSystem;
          }
        )
        ./servers/wireguard.nix
      ] ++ extraModules;
    };
}
