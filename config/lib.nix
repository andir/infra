let
  extraModules = (import (import ../nix/sources.nix).modules).all;
in
{
  # Inject my custom modules into the machine and set some common things.
  mkMachine = config: {
    imports = [
      config
    ] ++ extraModules;
  };
}
