let
  sources = import ./sources.nix;

  # morph needs a newer buildGoPackage since they track nixpkgs unstable
  unstable = import sources.nixpkgs-unstable {};

  overlays = [
    (_: pkgs: { inherit (import sources.niv {}) niv; })
    (_: _: { c3schedule = import sources.c3schedule {}; })
    (import ./packages { inherit sources; })
    (_: _: { nix-pre-commit-hooks = import (sources."pre-commit-hooks.nix"); })
    (
      _: pkgs: {
        grafana-dashboards = pkgs.symlinkJoin {
          name = "grafana-dashboards";
          paths = [
            ../config/servers/mon/grafana-dashboards
            # pkgs.fping_exporter.dashboard # Nice idea but doesn't work since this dashboard is in "import" format which contains placeholders for datasources
          ];
        };
      }
    )
    # FIXME: remove this once it works/broke things
    (
      _: _: let
        pkgs = import sources.felix-prosody-nixpkgs {};
      in
        {
          inherit (pkgs) prosody;
        }
    )
  ];

in
import sources.nixpkgs { inherit overlays; config = {}; }
