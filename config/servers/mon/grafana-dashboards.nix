{ pkgs, lib, ... }:
{
  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "Static dashboards";
      options.path = pkgs.grafana-dashboards;
    }
  ];
}
