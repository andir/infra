{ config, lib, pkgs, nodes, ... }:
let
  forAllNodes = func: lib.mapAttrs func nodes;

  hashConfig = config:
    let
      h = if config == null || config == {} then "" else builtins.hashString "sha256" (builtins.toJSON config);
    in lib.substring 0 8 h;

  # targetNames :: List String
  targetNames = lib.unique (lib.flatten (lib.attrValues (forAllNodes (_: v: lib.attrNames v.config.h4ck.monitoring.targets))));
  targetConfigurations = targetName:
    assert builtins.isString targetName;
    let
      nodesWithTarget = lib.filterAttrs (_: v: v != null) (forAllNodes (_: v: v.config.h4ck.monitoring.targets.${targetName} or null));
    in
      lib.mapAttrs' (_: v:
        let
          job_config = let val = v.job_config or {}; in if val == null then {} else val;
          hash = hashConfig job_config;
          name = if hash != "" then "${targetName}-${hash}" else targetName;
        in {
          inherit name;
          value = {
            inherit job_config;
            nodes = nodesWithTarget;
          };
        }) nodesWithTarget;

  targetSets = lib.fold (a: b: a // b) {} (map targetConfigurations targetNames);

  targets =
    assert builtins.isAttrs targetSets;
    (lib.mapAttrsToList
      (job_name: conf: conf.job_config // {
        inherit job_name;
        static_configs =
          lib.mapAttrsToList (n: v: {
            targets = [
              "${nodes.${n}.config.h4ck.monitoring.targetHost}:${toString v.port}"
            ];
          }) conf.nodes;
      })
      targetSets);
in {

  imports = [ ../profiles/hetzner-vm.nix ];

  services.prometheus = {
    enable = true;
    scrapeConfigs = lib.traceValSeq targets;
  };

  h4ck.monitoring.targets."node" = {
    port = 9100;
    job_config = { tls_config = {}; };
  };

  environment.etc."monitoring-targets".text = builtins.toJSON targets;
}
