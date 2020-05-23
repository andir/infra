let
  inherit (import ./lib.nix) mkMachine;
  pkgs = import ../nix;
  sources = import ../nix/sources.nix;
in
{

  network = {
    description = "foo";
    inherit pkgs;
    #nixConfig.post-build-hook = "${pkgs.writeScript "post-build-hook" ''
    #  #!${pkgs.stdenv.shell}
    #  set -ex
    #  echo "$@" > .buildpaths
    #''}";

    evalConfig = machineName:
      let
        prefix = sources."${machineName}-nixpkgs" or pkgs.path;
      in
        import (prefix + "/nixos/lib/eval-config.nix");
  };

  "jh4all.de" = mkMachine ./servers/jh4all.nix;
  iota = mkMachine ./servers/iota.nix;
  "kack.it" = mkMachine ./servers/kack-it;

  mail = mkMachine ./servers/mail;

  mon = mkMachine ./servers/mon;

  bertha = mkMachine ./servers/bertha;
}
