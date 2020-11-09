let
  inherit (import ./lib.nix) mkMachine;
  pkgs = import ../nix { };
  sources = import ../nix/sources.nix;
in
{

  network = {
    description = "foo";
    #inherit pkgs;
    #nixConfig.post-build-hook = "${pkgs.writeScript "post-build-hook" ''
    #  #!${pkgs.stdenv.shell}
    #  set -ex
    #  echo "$@" > .buildpaths
    #''}";

    inherit (pkgs) runCommand;

    lib = import (pkgs.path + "/lib");

    evalConfig = machineName:
      let
        prefix = sources."${machineName}-nixpkgs" or pkgs.path;
      in
      import (prefix + "/nixos/lib/eval-config.nix");
  };

  "jh4all.de" = mkMachine { config = ./servers/jh4all.nix; };
  iota = mkMachine { config = ./servers/iota.nix; };
  "kack.it" = mkMachine { config = ./servers/kack-it; };

  mail = mkMachine { config = ./servers/mail; };

  mon = mkMachine { config = ./servers/mon; };

  bertha = mkMachine { config = ./servers/bertha; };

  gallery = mkMachine { config = ./servers/gallery; };

  crappy = mkMachine {
    config = ./servers/crappy;
    system = "aarch64-linux";
  };
}
