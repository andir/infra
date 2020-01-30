{ pkgs, lib, ... }:
{
  services.grafana.provision.dashboards = [
    {
      name = "Static dashboards";
      options.path = ./grafana-dashboards;
    }
  ];
}
