{ pkgs, lib, config, nodes, ... }:
let
  verifiedNetfilter = { text, modules ? [ ] }:
    let
      file = pkgs.writeText "netfilter" text;
      vmTools = pkgs.vmTools.override {
        rootModules =
          [
            "virtio_pci"
            "virtio_mmio"
            "virtio_blk"
            "virtio_balloon"
            "virtio_rng"
            "ext4"
            "unix"
            "9p"
            "9pnet_virtio"
            "crc32c_generic"
          ] ++ modules;
      };

      check = vmTools.runInLinuxVM (
        pkgs.runCommand "nft-check"
          {
            buildInputs = [ pkgs.nftables ];
            inherit file;
          } ''
          set -ex
          # make sure protocols & services are known
          ln -s ${pkgs.iana-etc}/etc/protocol /etc/protocol
          ln -s ${pkgs.iana-etc}/etc/services /etc/services

          # test the configuration
          nft --file $file
          set +x
        ''
      );
    in
    "#checked with ${check}\n" + text;


  monitoringHosts = [ "crappy" ];
  monitoringPorts = lib.unique (lib.flatten (map (host: nodes.${host}.config.h4ck.monitoring.ports) monitoringHosts));

in
{
  imports = [
    # custom nixpkgs since I need a very specific version of systemd-networkd
    # and newer NixOS options for the same.
    ./nixpkgs.nix
    ./router.nix
    ../../profiles/server.nix
    ./unifi.nix
    ./nginx.nix
  ];

  h4ck.monitoring.targetHost = "fd21:a07e:735e:ffff::1";
  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::1/64"
      #  "172.20.24.1/32"
      #  "fd21:a07e:735e:ffff::1/128"
    ];
  };

  boot.loader.grub = {
    enable = true;
    version = 2;
    extraConfig = ''
      serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
      terminal_input serial;
      terminal_output serial;
    '';
    devices = [ "/dev/sda" "/dev/sdb" ];
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  deployment = {
    #   targetHost = "2a00:e67:1a6:0:20d:b9ff:fe41:6546";
    #targetHost = "10.250.11.254";
    targetHost = "fe80::3c29:d9ff:fe39:1adf%enp4s0";
    targetUser = "root";
    substituteOnDestination = false;
  };


  systemd.network.links = {
    "00-uplink" = {
      matchConfig.Path = "pci-0000:03:00.0";
      linkConfig = {
        NamePolicy = false;
        Name = "uplink";
      };
    };
  };
  systemd.network.netdevs = {
    "00-internal-bond" = {
      netdevConfig = {
        Name = "internal";
        Kind = "bond";
      };
    };

    "00-lan-vlan" = {
      netdevConfig = {
        Name = "lan";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 40;
      };
    };

    "00-oldlan-vlan" = {
      netdevConfig = {
        Name = "oldlan";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 11;
      };
    };

    "00-mgmt-vlan" = {
      netdevConfig = {
        Name = "mgmt";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 30;
      };
    };

    "00-sc-agx-vlan" = {
      netdevConfig = {
        Name = "sc-agx";
        Kind = "vlan";
      };
      vlanConfig = {
        Id = 42;
      };
    };

  };

  systemd.network.networks = {
    "00-internal-bond" = {
      matchConfig = {
        Name = "internal";
      };
      vlan = [ "oldlan" "lan" "mgmt" "sc-agx" ];
    };
    "00-bond0-1" = {
      matchConfig = {
        Path = "pci-0000:01:00.0";
      };
      networkConfig = {
        Bond = "internal";
      };
    };
    "00-bond0-2" = {
      matchConfig = {
        Path = "pci-0000:02:00.0";
      };
      networkConfig = {
        Bond = "internal";
      };
    };
    "00-oldlan" = {
      #      networkConfig.DHCPServer = false;
    };
    # "00-enp3s0" = {
    #   matchConfig = {
    #     Name = "enp3s0";
    #   };
    #   networkConfig = {
    #     DHCP = "yes";
    #   };
    # };
  };

  # router networkd configuration that actually puts addresses on interfaces,
  # configures the upstream interfaces, requests PD, …
  router = {
    enable = true;
    enableAvahiReflector = true;
    upstreamInterfaces = [ "uplink" ];
    downstreamInterfaces = [
      {
        interface = "lan";
        subnetId = "a";
        dnsOverTls = true;
        v4Addresses = [
          { address = "172.20.24.1"; prefixLength = 24; }
        ];
        v6Addresses = [
          { address = "fd21:a07e:735e:ff00::"; prefixLength = 64; }
        ];
      }
      {
        interface = "oldlan";
        subnetId = "b";
        v4Addresses = [
          { address = "10.250.11.254"; prefixLength = 24; }
        ];
        v6Addresses = [
          { address = "fd21:a07e:735e:ff01::"; prefixLength = 64; }
        ];
      }
      {
        interface = "mgmt";
        v4Addresses = [
          { address = "10.250.30.254"; prefixLength = 24; }
        ];
        v6Addresses = [
          { address = "fd21:a07e:735e:ff02::"; prefixLength = 64; }
        ];
      }
      {
        interface = "sc-agx";
        subnetId = "42";
        v4Addresses = [
          { address = "10.250.42.1"; prefixLength = 24; }
        ];
        v6Addresses = [
          { address = "fd21:a07e:735e:ff42::"; prefixLength = 64; }
        ];
      }
    ];
  };

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = verifiedNetfilter {
    modules = [
      #      "nft_nat"
    ];
    text = ''
      table inet filter {

        chain input {
          type filter hook input priority filter;

          iifname lo accept

          ct state {established, related} accept

          ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept

          ip6 nexthdr icmpv6 icmpv6 type echo-request accept
          ip protocol icmp icmp type echo-request accept

          tcp dport { 22, 80, 443 } accept

          iifname lan jump lan_input
          iifname oldlan jump lan_input
          iifname mgmt accept;
          iifname sc-agx jump agx_input

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: peer: "iifname ${peer.interfaceName} jump wg_peer_input;") config.h4ck.wireguardBackbone.peers)}

          # iifname mgmt jump lan_input # FIXME: mgmt input should be handled differently
          iifname uplink jump upstream_input


          counter log prefix "blocked incoming: " drop
        }

        chain wg_peer_input {
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
          ip6 nexthdr udp udp dport 6696 accept # babel
          ip6 nexthdr tcp tcp dport 9100 accept # node-exporter
          ip6 nexthdr tcp tcp dport 9113 accept # nginx-exporter
          ip6 nexthdr tcp tcp dport 9604 accept # fping4
          ip6 nexthdr tcp tcp dport 9606 accept # fping6
          ip6 nexthdr tcp tcp dport 179 accept # bgp
        }

        chain lan_input {
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
          udp sport bootpc udp dport bootps accept comment "DHCP clients"
          udp dport { domain, domain-s } accept
          tcp dport { domain, domain-s } accept
          ${lib.optionalString (config.router.enableAvahiReflector) ''
            udp dport { mdns } accept
            tcp dport { mdns } accept
          ''}
        }

        chain agx_input {
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
          udp sport bootpc udp dport bootps accept comment "DHCP clients"
          udp dport { domain, domain-s } accept
          tcp dport { domain, domain-s } accept
        }

        chain upstream_input {
          # make dhcp client and ipv6 ra work on the uplink interface
          udp sport bootps udp dport bootpc accept
          udp sport bootps udp dport bootpc accept
          ip6 nexthdr icmpv6 icmpv6 type { nd-router-advert } accept
          ip6 nexthdr udp udp sport dhcpv6-server udp dport dhcpv6-client accept
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: peer: "udp dport ${toString peer.localPort} accept") config.h4ck.wireguardBackbone.peers)}
        }

        chain output {
          type filter hook output priority filter; policy accept;
          accept
        }

        chain forward {
          type filter hook forward priority filter;

          iif lo accept

          ct state {established, related} accept

          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept

          # everything can go out
          oifname uplink accept

          oifname lan iifname oldlan accept
          oifname oldlan iifname lan accept


          oifname lan jump forward_to_lan
          oifname oldlan jump forward_to_lan
          oifname mgmt jump forward_to_mgmt

          oifname sc-agx iifname lan accept
          oifname sc-agx iifname oldlan accept
          oifname sc-agx ip6 nexthdr tcp tcp dport 22 accept

          oifname "wg-*" jump forward_to_wg

          log prefix "not forwarding: " reject
        }

        chain forward_to_wg {
          iifname lan accept;
          iifname oldlan accept;
          iifname "wg-*" accept;
        }

        chain forward_to_lan {
          tcp dport { 22 } accept
          tcp dport { 6882 } accept;

          ip6 nexthdr tcp tcp dport { 22, 80, 443, 655, 4001, 9100, 22000, 16686 } accept
          # allow mosh
          udp dport 60000-61000 accept

          # forward to monitoring ports, final access control happens on each device
          ${lib.concatMapStringsSep "\n" (port: "tcp dport ${toString port} accept") monitoringPorts}
          reject
        }

        chain forward_to_mgmt {
          reject
        }
      }
      table ip nat {
        # map somemap {
        #   type inet_service: ipv4_addr;
        #   flags constant,interval;
        #   elements = {
        #     20000-20004: 192.168.0.1,
        #     20005-20009: 192.168.0.2
        #     }
        # }

        chain prerouting {
           type nat hook prerouting priority dstnat;
           # tcp dport { 4001 } dnat to $somewhere
           iifname uplink tcp dport { 6882 } dnat to 10.250.11.249

           # dnat udp dport map @somemap;
        }
        chain postrouting {
           type nat hook postrouting priority srcnat;
           oifname uplink masquerade
           iifname oldlan oifname wg-dn42_cccda snat 172.20.24.1
        }
      }
    '';
  };


  # allow local unbound-control invocations
  #systemd.tmpfiles.rules = [
  #  "d /run/unbound 550 unbound nogroup - "
  #];
  security.acme.certs."epsilon.rammhold.de" = {
    group = "cert-users";
  };

  systemd.services."acme-epsilon.rammhold.de.service".after = [ "unbound.service" ];
  users.groups.cert-users.members = [ "nginx" "unbound" ];
  systemd.services.unbound = {
    wantedBy = [ "network-online.target" ];
  };
  services.unbound.extraConfig =
    let
      privateKey = config.security.acme.certs."epsilon.rammhold.de".directory + "/key.pem";
      publicKey = config.security.acme.certs."epsilon.rammhold.de".directory + "/cert.pem";
    in
    ''

      server:
        tls-service-key: ${privateKey}
        tls-service-pem: ${publicKey}
      remote-control:
        control-enable: yes
        control-interface: /run/unbound/unbound.ctl
    '';
  users.users.root.initialPassword = "password";

  environment.systemPackages = [ pkgs.ldns pkgs.telnet pkgs.ethtool ];


  h4ck.dn42 = {
    enable = true;
    bgp = {
      asn = 4242423991;
      staticRoutes = {
        ipv4 = [
          "172.20.24.0/24"
          "172.20.25.0/25"
          "172.20.199.0/24"
        ];
        ipv6 = [
          #          "fd42:4242:4200::/40"
          "fd21:a07e:735e::/48"
        ];
      };
    };
    peers = {
      iota = {
        tunnelType = null;
        interfaceName = "wg-iota";
        bgp = {
          asn = 4242423991;
        };
        addresses = {
          ipv6.local_address = "fe80::1";
          ipv6.remote_address = "fe80::3";
          ipv6.prefix_length = 64;
        };
      };

      cccda = {
        tunnelType = "wireguard";
        wireguardConfig = {
          localPort = 43011;
          remotePort = 43011;
          remoteEndpoint = "core1.darmstadt.ccc.de";
          remotePublicKey = "iB8P2uuKGISflakJiHMGuBR7zKK44qx+ioqeBN0sEnk=";
        };
        bgp = {
          asn = 4242420101;
          local_pref = 100;
          multi_protocol = false;
        };
        addresses = {
          ipv4 = {
            local_address = "172.22.248.18";
            remote_address = "172.22.248.17";
            prefix_length = 30;
          };
          ipv6 = {
            local_address = "fe80::f00";
            remote_address = "fe80::ccc:da";
            prefix_length = 64;
          };
        };
      };

      kn = {
        tunnelType = "wireguard";
        mtu = 1408;
        wireguardConfig = {
          localPort = 42017;
          remotePort = 42017;
          remoteEndpoint = "t4-2.high5.nl";
          remotePublicKey = "G1PuSw6I6nZYYD4LcqtkwxoDE/KLEuF2mZpCMTNONB4=";
        };
        bgp = {
          asn = 4242421239;
          local_pref = 100;
        };
        addresses = {
          ipv6 = {
            local_address = "fdfd:3ba:342d:a7d2::1";
            remote_address = "fdfd:3ba:342d:a7d2::";
            prefix_length = 127;
          };
        };
      };

      flokli_ws = {
        tunnelType = "wireguard";
        mtu = 1500;
        wireguardConfig = {
          localPort = 42018;
          remoteEndpoint = null;
          remotePublicKey = "Fq5x85Drr0f/3EIXMyANPmu3dZMlTAWebjJ1cI91R3A=";
        };
        bgp = {
          asn = 4242422100;
          local_pref = 100;
        };
        addresses = {
          ipv6 = {
            local_address = "fe80::1";
            remote_address = "fe80::2";
            prefix_length = 64;
          };
        };
      };
    };
  };

}
