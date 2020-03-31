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
      lib.mapAttrs' (
        _: v:
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
          }
      ) nodesWithTarget;

  targetSets = lib.fold (a: b: a // b) {} (map targetConfigurations targetNames);

  targets =
    assert builtins.isAttrs targetSets;
    (
      lib.mapAttrsToList
        (
          job_name: conf:
            { inherit job_name; }
            // conf.job_config
            // (
              if (lib.attrByPath [ "static_configs" ] false conf.job_config) == false then {
                static_configs =
                  lib.mapAttrsToList (
                    n: v:
                      let
                        targetHost = if v ? targetHost && v.targetHost != null then v.targetHost else
                          nodes.${n}.config.h4ck.monitoring.targetHost;
                      in {
                        targets = [
                          "${targetHost}:${toString v.port}"
                        ];
                      }
                  ) conf.nodes;
              } else {}
            )
        )
        targetSets
    );
in
{
  services.prometheus.scrapeConfigs = targets;
}
