{ pkgs, lib, ... }:
{
  services.grafana.provision.dashboards = [
    {
      name = "Static dashboards";
      options.path = pkgs.grafana-dashboards;
    }
  ];
}
