{ lib, config, ... }:
with lib;
let
  v4Srcs = [ "148.251.9.69/32" "95.216.144.32/32" ];
  v6Srcs = [ "2a01:4f8:201:6344::/64" "2a01:4f9:c010:c50::/64" ];

  mkFirewallRules = name: port: {
    networking.firewall.extraCommands = lib.concatStringsSep "\n" (
      (map (v4Src: ''iptables -A nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}"'') v4Srcs)
      ++ (map (v6Src: ''ip6tables -A nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"'') v6Srcs)
    );
    networking.firewall.extraStopCommands = lib.concatStringsSep "\n" (
      (map (v4Src: ''iptables -D nixos-fw -p tcp --dport ${toString port} -s ${v4Src} -j ACCEPT -m comment --comment "prometheus ${name}" || :'') v4Srcs)
      ++ (map (v6Src: ''ip6tables -D nixos-fw -p tcp --dport ${toString port} -s ${v6Src} -j ACCEPT -m comment --comment "prometheus ${name}"  || :'') v6Srcs)
    );

  };

  mkExporter = name: port: conf: mkMerge [
    {
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
    }
    (mkFirewallRules name port)
  ];

  monitoringTarget = { name, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      name = mkOption {
        type = types.str;
      };
      targetHost = mkOption {
        type = types.nullOr types.str;
        default = null;
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

  dnsMonitoringEntry = { name, ... }: {
    options = {
      queryType = mkOption {
        type = types.str;
        default = "ANY";
      };
      queryName = mkOption {
        type = types.str;
      };
    };
    config = {
      queryName = mkDefault name;
    };
  };

  icmpMonitoringEntry = { name, ... }: {
    options = {
      targetName = mkOption {
        type = types.str;
      };
      protocol = mkOption {
        type = types.enum [ "ip4" "ip6" null ];
        default = null;
      };
    };
    config = {
      targetName = mkDefault name;
    };
  };

  smtpMonitoringEntry = { name, ... }: {
    options = {
      targetName = mkOption {
        type = types.str;
      };

      startTls = mkOption {
        type = types.bool;
        default = true;
      };
    };
    config = {
      targetName = name;
    };
  };

  fpingMonitoringEntry = { name, ... }: {
    options = {
      targetName = mkOption {
        type = types.str;
      };
      config = {
        targetName = name;
      };
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

    dns = mkOption {
      type = types.attrsOf (types.submodule dnsMonitoringEntry);
      default = {};
    };

    icmp = mkOption {
      type = types.attrsOf (types.submodule icmpMonitoringEntry);
      default = {};
    };

    smtp = mkOption {
      type = types.attrsOf (types.submodule smtpMonitoringEntry);
      default = {};
    };

    fping4 = mkOption {
      type = types.attrsOf (types.submodule fpingMonitoringEntry);
      default = {
        "1.1.1.1" = {};
        "8.8.8.8" = {};
        "9.9.9.9" = {};
        "google.com" = {};
        "chaos-darmstadt.de" = {};
        "as6766.net" = {};
        "nynex.de" = {};
        "hetzner.de" = {};
        "eqixfr5-bb1.nynex.de" = {};
        "eqixfr5-bb2.nynex.de" = {};
        "ixfr3-bb1.nynex.de" = {};
        "usi-corea.nynex.de" = {};
      };
    };

    fping6 = mkOption {
      type = types.attrsOf (types.submodule fpingMonitoringEntry);
      default = {
        "2606:4700:4700::1111" = {};
        "2001:4860:4860::8888" = {};
        "2620:fe::fe" = {};
        "google.com" = {};
        "chaos-darmstadt.de" = {};
        "as6766.net" = {};
        "nynex.de" = {};
        "hetzner.de" = {};
        "eqixfr5-bb1.nynex.de" = {};
        "eqixfr5-bb2.nynex.de" = {};
        "ixfr3-bb1.nynex.de" = {};
      };
    };

  };
  config = mkIf config.h4ck.monitoring.enable (
    mkMerge [
      (
        mkExporter "node" 9100 {
          enabledCollectors = [ "systemd" ];
        }
      )

      # on nodes running prometheus also scrape prometheus own metrics
      (
        mkIf config.services.prometheus.enable {
          h4ck.monitoring.targets.prometheus = {
            port = 9090;
          };
        }
      )

      # enable the nginx exporter if nginx is used on the host
      (
        mkIf config.services.nginx.enable (
          mkMerge [
            (mkExporter "nginx" 9113 {})
            {
              services.nginx.statusPage = mkDefault true;
            }
          ]
        )
      )

      # enable dovecot monitoring
      # currently deactivated since the old exporter isn't really great
      # and the new configuration syntax doesn't seem to work :(
      (
        mkIf (config.services.dovecot2.enable) (
          {
            h4ck.monitoring.targets.prometheus = {
              port = 9166;
            };
            services.dovecot2.extraConfig = ''
              service stats {
                inet_listener http {
                  port = 9166
                }
              }
            '';
          }
        )
      )

      (
        mkIf config.services.knot.enable (
          mkMerge [
            {
              h4ck.prometheus.exporters.knot_exporter.enable = true;
              h4ck.monitoring.targets.knot = {
                port = 9053;
              };
              h4ck.authorative-dns.enableStats = true;
            }
            (mkFirewallRules "knot" 9053)
          ]
        )
      )

      (
        mkIf (config.h4ck.monitoring.fping4 != {} || config.h4ck.monitoring.fping6 != {}) (
          mkMerge [
            {
              h4ck.prometheus.exporters.fping_exporter.enable = true;
              h4ck.monitoring.targets.fping_exporter4 = {
                port = config.h4ck.prometheus.exporters.fping_exporter.port4;
              };
              h4ck.monitoring.targets.fping_exporter6 = {
                port = config.h4ck.prometheus.exporters.fping_exporter.port6;
              };
            }
            (mkFirewallRules "fping4" config.h4ck.prometheus.exporters.fping_exporter.port4)
            (mkFirewallRules "fping6" config.h4ck.prometheus.exporters.fping_exporter.port6)
            {
              h4ck.monitoring.targets = (
                lib.mapAttrs' (
                  target: _: lib.nameValuePair "fping4_${target}" {
                    port = config.h4ck.prometheus.exporters.fping_exporter.port4;
                    job_config = {
                      metrics_path = "/probe";
                      static_configs = [
                        {
                          targets = [
                            target
                          ];
                        }
                      ];
                      relabel_configs = [
                        {
                          source_labels = [ "__address__" ];
                          target_label = "__param_target";
                        }
                        {
                          source_labels = [ "__param_target" ];
                          target_label = "target";
                        }
                        {
                          target_label = "__address__";
                          replacement = config.h4ck.monitoring.targetHost + ":${toString config.h4ck.prometheus.exporters.fping_exporter.port4}";
                        }
                      ];
                    };

                  }
                )
                  config.h4ck.monitoring.fping4
              );
            }
            {
              h4ck.monitoring.targets = (
                lib.mapAttrs' (
                  target: _: lib.nameValuePair "fping6_${target}" {
                    port = config.h4ck.prometheus.exporters.fping_exporter.port6;
                    job_config = {
                      metrics_path = "/probe";
                      static_configs = [
                        {
                          targets = [
                            target
                          ];
                        }
                      ];
                      relabel_configs = [
                        {
                          source_labels = [ "__address__" ];
                          target_label = "__param_target";
                        }
                        {
                          source_labels = [ "__param_target" ];
                          target_label = "target";
                        }
                        {
                          target_label = "__address__";
                          replacement = config.h4ck.monitoring.targetHost + ":${toString config.h4ck.prometheus.exporters.fping_exporter.port6}";
                        }
                      ];
                    };
                  }
                )
                  config.h4ck.monitoring.fping6
              );
            }

          ]
        )
      )


      (
        mkIf (config.h4ck.monitoring.dns != {} || config.h4ck.monitoring.icmp != {} || config.h4ck.monitoring.smtp != {}) (
          mkMerge [
            {
              services.prometheus.exporters.blackbox.enable = true;
              h4ck.monitoring.targets.blackbox = {
                port = 9115;
              };
            }
            {
              h4ck.blackbox_exporter.config = {
                modules =
                  (
                    lib.mapAttrs'
                      (
                        zone: params: lib.nameValuePair
                          "dns_${zone}"
                          {
                            prober = "dns";
                            dns = {
                              query_type = params.queryType;
                              query_name = params.queryName;
                            };
                          }
                      ) config.h4ck.monitoring.dns
                  )
                  // (
                    lib.mapAttrs'
                      (
                        target: params: lib.nameValuePair
                          "icmp_${target}" {
                          prober = "icmp";
                          timeout = "1s";
                          icmp =
                            (
                              lib.optionalAttrs (params.protocol != null) {
                                preferred_ip_protocol = params.protocol;
                                ip_protocol_fallback = true;
                              }
                            )
                          ;
                        }
                      ) config.h4ck.monitoring.icmp
                  )
                  // (
                    lib.mapAttrs'
                      (
                        target: params: lib.nameValuePair
                          "smtp_${target}" {
                          prober = "tcp";
                          timeout = "5s";
                          tcp.query_response = [
                            { expect = "^220 ([^ ]+) ESMTP (.+)$"; }
                            { send = "EHLO prober"; }
                          ] ++ (
                            lib.optionals params.startTls [
                              { expect = "^250-STARTTLS"; }
                              { send = "STARTTLS"; }
                              { expect = "^220"; }
                              { starttls = true; }
                              { send = "EHLO prober"; }
                              { expect = "^250-AUTH"; }
                            ]
                          ) ++ [
                            { send = "QUIT"; }
                          ];
                        }
                      ) config.h4ck.monitoring.smtp
                  )
                ;
              };
            }
            (
              {
                h4ck.monitoring.targets = (
                  lib.mapAttrs' (
                    zone: params: lib.nameValuePair
                      "blackbox_dns_${zone}"
                      {
                        port = 9115;
                        job_config = {
                          params.module = [ "dns_${zone}" ];
                          metrics_path = "/probe";
                          static_configs = [
                            {
                              targets = [
                                "1.1.1.1"
                                "8.8.4.4"
                                "8.8.8.8"
                                "9.9.9.9"
                              ];
                            }
                          ];
                          relabel_configs = [
                            {
                              source_labels = [ "__address__" ];
                              target_label = "__param_target";
                            }
                            {
                              source_labels = [ "__param_target" ];
                              target_label = "instance";
                            }
                            {
                              target_label = "__address__";
                              replacement = config.h4ck.monitoring.targetHost + ":9115";
                            }

                          ];
                        };
                      }
                  ) config.h4ck.monitoring.dns
                ) // (
                  lib.mapAttrs' (
                    target: params: lib.nameValuePair
                      "blackbox_icmp_${target}" {
                      port = 9115;
                      job_config = {
                        params.module = [ "icmp_${target}" ];
                        metrics_path = "/probe";
                        static_configs = [
                          {
                            targets = [
                              params.targetName
                            ];
                          }
                        ];
                        relabel_configs = [
                          {
                            source_labels = [ "__address__" ];
                            target_label = "__param_target";
                          }
                          {
                            source_labels = [ "__param_target" ];
                            target_label = "instance";
                          }
                          {
                            target_label = "__address__";
                            replacement = config.h4ck.monitoring.targetHost + ":9115";
                          }
                        ];
                      };
                    }
                  ) config.h4ck.monitoring.icmp
                ) // (
                  lib.mapAttrs' (
                    target: params: lib.nameValuePair
                      "smtp_${target}" {
                      port = 9115;
                      job_config = {
                        params.module = [ "smtp_${target}" ];
                        metrics_path = "/probe";
                        static_configs = [
                          {
                            targets = [
                              params.targetName
                            ];
                          }
                        ];
                        relabel_configs = [
                          {
                            source_labels = [ "__address__" ];
                            target_label = "__param_target";
                          }
                          {
                            source_labels = [ "__param_target" ];
                            target_label = "instance";
                          }
                          {
                            target_label = "__address__";
                            replacement = config.h4ck.monitoring.targetHost + ":9115";
                          }
                        ];
                      };
                    }
                  ) config.h4ck.monitoring.smtp
                );
              }
            )
            (mkFirewallRules "blackbox" 9115)
          ]
        )
      )
    ]
  );
}
