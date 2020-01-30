let
  inherit (import ./lib.nix) mkMachine;
  pkgs = import ../nix;
in {

  network = {
    description = "foo";
    inherit pkgs;
    #nixConfig.post-build-hook = "${pkgs.writeScript "post-build-hook" ''
    #  #!${pkgs.stdenv.shell}
    #  set -ex
    #  echo "$@" > .buildpaths
    #''}";
  };

  "jh4all.de" = mkMachine ./servers/jh4all.nix;
  "gitlab-runner" = mkMachine ./servers/gitlab-runner.nix;
  "kack.it" = mkMachine ./servers/kack-it.nix;

  mail = mkMachine ./servers/mail;

  mon = mkMachine ./servers/mon;
}
