let
  pkgs = import ./nix;

  evalServers = pkgs.writeScriptBin "eval-servers" ''
    nix eval '(map (n: n.config.system.build.toplevel.drvPath) (builtins.attrValues ((import ${pkgs.morph.lib}/eval-machines.nix) { networkExpr = ./config/servers.nix; }).nodes))'
  '';
in pkgs.mkShell {
  buildInputs = with pkgs; [
    bash
    evalServers
    git
    gnutar
    gzip
    hcloud
    morph
    niv
    nix
    openssh
  ];
}
