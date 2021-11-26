let
  pkgs = import ./nix { };

  evalServers = pkgs.writeScriptBin "eval-servers" ''
    nix eval '(map (n: n.config.system.build.toplevel.drvPath) (builtins.attrValues ((import ${pkgs.morph.lib}/eval-machines.nix) { networkExpr = ./config/servers.nix; }).nodes))'
  '';

  grafana-devel = pkgs.unstable.callPackage ./tools/grafana-devel.nix { };

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
    npins
    nixUnstable
    nixpkgs-fmt
    openssh
    gitAndTools.git-bug
  ];

  inherit (pre-commit-hooks) shellHook;

  NPINS_FOLDER = toString ./nix/npins;
}
