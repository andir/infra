{ pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [ 5863 655 ];
  networking.firewall.allowedUDPPorts = [ 5863 655 ];
  networking.firewall.extraCommands = ''
    ip6tables -t nat -I PREROUTING 1 -p tcp --dport 5863 -j DNAT --to fdd::2
    ip6tables -t nat -I PREROUTING 1 -p udp --dport 5863 -j DNAT --to fdd::2
    ip6tables -t nat -I PREROUTING 1 -p tcp --dport 655 -j DNAT --to-destination '[fdd::2]:5863'
    ip6tables -t nat -I PREROUTING 1 -p udp --dport 655 -j DNAT --to-destination '[fdd::2]:5863'

  '';
  networking.firewall.extraStopCommands = ''
    ip6tables -t nat -D PREROUTING -p tcp --dport 5863 -j DNAT --to fdd::2 || :
    ip6tables -t nat -D PREROUTING -p udp --dport 5863 -j DNAT --to fdd::2 || :
    ip6tables -t nat -D PREROUTING -p tcp --dport 655 -j DNAT --to fdd::2 || :
    ip6tables -t nat -D PREROUTING -p udp --dport 655 -j DNAT --to fdd::2 || :
    ip6tables -t nat -D PREROUTING -p tcp --dport 655 -j DNAT --to-destination '[fdd::2]:5863' || :
    ip6tables -t nat -D PREROUTING -p udp --dport 655 -j DNAT --to-destination '[fdd::2]:5863' || :
  '';

  containers.wan-party = {
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    localAddress = "100.64.0.2";
    localAddress6 = "fdd::2";
    hostAddress = "100.64.0.1";
    hostAddress6 = "fdd::1";
    forwardPorts = [
      {
        hostPort = 5863;
        containerPort = 5863;
        protocol = "tcp";
      }
      {
        hostPort = 5863;
        containerPort = 5863;
        protocol = "udp";
      }

      {
        hostPort = 655;
        containerPort = 5863;
        protocol = "tcp";
      }
      {
        hostPort = 655;
        containerPort = 5863;
        protocol = "udp";
      }
    ];
    config = { pkgs, ... }:
      {
        imports = [ ./xonotic.nix ];
        networking.firewall.allowedTCPPorts = [ 5863 655 80 ];
        networking.firewall.allowedUDPPorts = [ 5863 655 80 ];
        environment.systemPackages = [ pkgs.tinc_pre ];
        services.nginx = {
          enable = true;
          package = pkgs.nginx.override { modules = [ pkgs.nginxModules.fancyindex ]; };
          virtualHosts."wanparty" = {
            root = "/data";
            extraConfig = ''
              fancyindex on;
              fancyindex_exact_size off;
            '';
          };
        };
        services.tinc.networks = {
          wan-party = {
            package = pkgs.tinc_pre;
            name = "wanparty"; # node name
            interfaceType = "tap";
            ed25519PrivateKeyFile = "/etc/tinc/wan-party/ed25519_key.priv";

            extraConfig = ''
              Mode = switch
              Broadcast = yes
              AutoConnect = yes
              Forwarding = internal
              Subnet = 192.0.2.0/24
              Port = 5863
            '';
          };
        };
        networking.useNetworkd = true;
        networking.useHostResolvConf = false;
        systemd.network.networks."wanparty" = {
          matchConfig.Name = "tinc.wan-party";
          addresses = [
            {
              addressConfig.Address = "192.0.2.1/24";
            }
          ];
        };
      };
  };

  systemd.services.wan-party-invites = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      exec ${pkgs.python3.withPackages (p: [ p.irc ])}/bin/python ${./invite-bot.py} '#cda-lan'
    '';
  };
}
