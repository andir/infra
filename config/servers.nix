let
  inherit (import ./lib.nix) mkMachine;
in {
  network = {
    description = "foo";
    pkgs = import ../nix;
  };

  "www.jh4all.de" = mkMachine ./servers/jh4all.nix;
  "gitlab-runner" = mkMachine ./servers/gitlab-runner.nix;
  "kack.it" = mkMachine ./servers/kack-it.nix;
}
