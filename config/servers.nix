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

  "jh4all.de" = mkMachine {
    name = "jh4all.de";
    config = ./servers/jh4all.nix;
  };
  iota = mkMachine {
    name = "iota";
    config = ./servers/iota;
  };
  "kack.it" = mkMachine {
    name = "kack.it";
    config = ./servers/kack-it;
  };

  mail = mkMachine {
    name = "mail";
    config = ./servers/mail;
  };

  mon = mkMachine {
    name = "mon";
    config = ./servers/mon;
  };

  bertha = mkMachine {
    name = "bertha";
    config = ./servers/bertha;
  };

  gallery = mkMachine {
    name = "gallery";
    config = ./servers/gallery;
  };

  crappy = mkMachine {
    name = "crappy";
    config = ./servers/crappy;
    system = "aarch64-linux";
  };

  kappa = mkMachine {
    name = "kappa";
    config = ./servers/kappa;
    system = "x86_64-linux";
  };

  nixos-dev = mkMachine {
    name = "nixos.dev";
    config = ./servers/nixos-dev;
    system = "x86_64-linux";
  };
}
