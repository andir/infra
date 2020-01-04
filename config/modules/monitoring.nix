{ lib, config, ... }:
with lib;
let
  v4Src = "148.251.9.69/32";
  v6Src = "2a01:4f8:201:6344::/64";
  mkExporter = name: port: conf: {
    services.prometheus.exporters.${name} = mkMerge [
      {
        enable = mkDefault true;
        port = mkDefault port;
        openFirewall = mkDefault false;
      }
      conf
    ];
    h4ck.monitoring.targets.${name} = {
      inherit port;
    };
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}"
      ip6tables -A nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}" || :
      ip6tables -D nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"  || :
    '';
  };

  monitoringTarget = { name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      name = mkOption {
        type = types.str;
      };
      port = mkOption {
        type = types.port;
      };
      job_config = mkOption {
        type = types.nullOr types.attrs;
        default = null;
      };
    };
    config = {
      inherit name;
    };
  };
in
{
  options.h4ck.monitoring = {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    targetHost = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    targets = mkOption {
      type = types.attrsOf (types.submodule monitoringTarget);
    };
  };
  config = mkIf config.h4ck.monitoring.enable (mkMerge [
    (mkExporter "node" 9100 {
      enabledCollectors = [ "systemd" ];
    })

    # enable the nginx exporter if nginx is used on the host
    (mkIf config.services.nginx.enable (mkMerge [
      (mkExporter "nginx" 9113 {})
      {
        services.nginx.statusPage = mkDefault true;
      }
    ]))
  ]);
}
