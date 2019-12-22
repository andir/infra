let
  v4Src = "148.251.9.69/32";
  v6Src = "2a01:4f8:201:6344::/64";
  mkExporter = name: port: conf: {
    services.prometheus.exporters.${name} = {
      enable = true;
      inherit port;
      openFirewall = false;
    } // conf;
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}"
      ip6tables -A nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}" || :
      ip6tables -D nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"  || :
    '';
  };
in
{ imports = [
    (mkExporter "node" 9100 {
      enabledCollectors = [ "systemd" ];
    })
    (mkExporter "blackbox" 9101 {
      enable = false;
      configFile = ''
      '';
    })
  ];
}
