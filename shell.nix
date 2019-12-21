let
  pkgs = import ./nix;

  evalServers = pkgs.writeScriptBin "eval-servers" ''
    nix eval '(map (n: n.config.system.build.toplevel.drvPath) (builtins.attrValues ((import ${pkgs.morph.lib}/eval-machines.nix) { networkExpr = ./config/servers.nix; }).nodes))'
  '';
  myNix = pkgs.enableDebugging(pkgs.nix);
in pkgs.mkShell {
  buildInputs = with pkgs; [ niv morph hcloud evalServers myNix myNix.debug ];
}
