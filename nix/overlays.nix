{ system, config }:
let
  sources = import ./sources.nix;
in
[
  (_: pkgs: { inherit (import sources.niv { }) niv; })
  (_: _: { c3schedule = import sources.c3schedule { }; })
  (import ./packages { inherit sources system config; })
  (_: _: { nix-pre-commit-hooks = import (sources."pre-commit-hooks.nix"); })
  (self: _: { npmlock2nix = self.callPackage sources.npmlock2nix { }; })
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
  # With 20.09 nixos-install will have another version of Nix in it's closure for flakes support.
  (_: pkgs: { nixUnstable = pkgs.nix; })
]
