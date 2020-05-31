let
  pkgs = import ./nix;

  evalServers = pkgs.writeScriptBin "eval-servers" ''
    nix eval '(map (n: n.config.system.build.toplevel.drvPath) (builtins.attrValues ((import ${pkgs.morph.lib}/eval-machines.nix) { networkExpr = ./config/servers.nix; }).nodes))'
  '';

  grafana-devel = pkgs.callPackage ./tools/grafana-devel.nix {};

  pre-commit-hooks = pkgs.nix-pre-commit-hooks.run {
    src = ./.;
    hooks = {
      nixpkgs-fmt.enable = true;
    };
  };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    evalServers
    git
    git-lfs
    gnutar
    grafana-devel
    gzip
    hcloud
    morph
    niv
    nix
    nixpkgs-fmt
    openssh
  ];

  inherit (pre-commit-hooks) shellHook;
}
