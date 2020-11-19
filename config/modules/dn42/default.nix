{ config, lib, pkgs, ... }:
let
  inherit (lib)
    attrValues
    concatMapStringsSep
    concatStrings
    concatStringsSep
    filterAttrs
    flatten
    hasAttr
    hasPrefix
    listToAttrs
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optional
    optionalAttrs
    optionalString
    range
    types
    ;

  cfg = config.h4ck.dn42;
  wireguardKeyType = with lib; types.addCheck types.str (v: (stringLength v) > 40);
in
{
  options.h4ck.dn42 = {
    enable = mkEnableOption "enable dn42 configuration";
    enableDebugLogging = mkEnableOption "dn42 bgp logging";

    srcpref = mkOption {
      type = types.submodule {
        options = {
          v4Address = mkOption { type = types.nullOr types.str; default = null; };
          v6Address = mkOption { type = types.nullOr types.str; default = null; };
        };
      };
    };
    bgp = mkOption {
      type = types.submodule {
        options = {
          asn = mkOption { type = types.ints.unsigned; };
          routerId = mkOption { type = types.str; };
          staticRoutes = mkOption {
            type = types.submodule {
              options = {
                ipv4 = mkOption { type = types.listOf types.str; default = [ ]; };
                ipv6 = mkOption { type = types.listOf types.str; default = [ ]; };
              };
            };
          };
        };
      };
    };
    peers = mkOption
      {
        type = (
          types.attrsOf (
            types.submodule {
              options = {
                tunnelType = mkOption {
                  type = types.nullOr (types.enum [ "wireguard" ]);
                  description = "tunnel technology used";
                };
                mtu = mkOption {
                  type = types.nullOr types.ints.unsigned;
                  default = null;
                  description = "mtu on the interface";
                };
                interfaceName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                wireguardConfig = mkOption {
                  type = types.submodule {
                    options = {
                      localPort = mkOption { type = types.ints.unsigned; };
                      remoteEndpoint = mkOption { type = types.nullOr types.str; };
                      remotePort = mkOption { type = types.port; };
                      remotePublicKey = mkOption { type = wireguardKeyType; };
                    };
                  };
                };
                bgp = mkOption {
                  type = types.submodule {
                    options = {
                      asn = mkOption { type = types.ints.unsigned; };
                      announce = mkOption { type = types.enum [ "all" "own" ]; default = "own"; };
                      accept = mkOption { type = types.enum [ "all" "own" ]; default = "own"; };
                      local_pref = mkOption { type = types.ints.unsigned; };
                      #export_med = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
                      export_prepend = mkOption { type = types.ints.unsigned; default = 0; };
                      import_prepend = mkOption { type = types.ints.unsigned; default = 0; };
                      import_limit = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
                      import_reject = mkOption { type = types.bool; default = false; };
                      export_reject = mkOption { type = types.bool; default = false; };
                      multi_protocol = mkOption { type = types.bool; default = true; };
                    };
                  };
                };
                addresses = mkOption {
                  type = types.submodule {
                    options = {
                      ipv6 = mkOption {
                        default = null;
                        type = types.nullOr (
                          types.submodule {
                            options = {
                              local_address = mkOption { type = types.str; };
                              remote_address = mkOption { type = types.str; };
                              prefix_length = mkOption { type = types.ints.unsigned; default = 128; };
                            };
                          }
                        );
                      };
                      ipv4 = mkOption {
                        default = null;
                        type = types.nullOr (
                          types.submodule {
                            options = {
                              local_address = mkOption { type = types.str; };
                              remote_address = mkOption { type = types.str; };
                              prefix_length = mkOption { type = types.ints.unsigned; default = 32; };
                            };
                          }
                        );
                      };
                    };
                  };
                };
              };
            }
          )
        );
        default = { };
      } // {
      check = v: (if v.tunnelType == "wireguard" then hasAttr "wireguardConfig" v else true);
    };
  };

  config =
    let
      wireguardPeers = filterAttrs (n: v: v.tunnelType == "wireguard" && v ? wireguardConfig) cfg.peers;

      wireguardInterfaceNameMapping = mapAttrs (_: v: v.interfaceName) (filterAttrs (n: v: hasPrefix "wg-dn42_" v.interfaceName) config.h4ck.wireguardBackbone.peers);
      wireguardInterfaceNames = attrValues wireguardInterfaceNameMapping;

      interfaceNames = wireguardInterfaceNames ++ (mapAttrsToList (_: p: p.interfaceName) (filterAttrs (_: p: p.interfaceName != null) cfg.peers));
      interfaceNameMapping = wireguardInterfaceNameMapping;


      bgpPeers =
        lib.mapAttrsToList
          (
            name: v: {
              inherit name;
              interfaceName = if v.interfaceName != null then v.interfaceName else interfaceNameMapping."dn42_${name}";
              inherit (v) bgp;
            } // (
              optionalAttrs (v.addresses.ipv4 != null) {
                remoteV4 = v.addresses.ipv4.remote_address;
              }
            ) // (
              optionalAttrs (v.addresses.ipv6 != null) {
                remoteV6 = v.addresses.ipv6.remote_address;
              }
            )
          )
          cfg.peers;

    in
    mkIf cfg.enable {
      h4ck.bird.enable = true;

      environment.systemPackages = with pkgs; [ mtr tcpdump ];

      boot.kernel.sysctl = {
        "net.ipv6.all.default.forwarding" = 1;
      } // (
        listToAttrs (map (iface: nameValuePair "net.ipv4.conf.${iface}.forwarding" 1) interfaceNames)
      );
      networking.firewall = {
        checkReversePath = false;
        interfaces = lib.listToAttrs (
          map
            (
              name: nameValuePair name {
                allowedTCPPorts = [ 179 ];
              }
            )
            interfaceNames
        );
        extraCommands = concatStringsSep "\n" (
          flatten (
            map
              (
                iiface: (
                  map
                    (
                      oiface:
                      if iiface != oiface then [
                        "iptables -A FORWARD -i ${iiface} -o ${oiface} -j ACCEPT"
                        "ip6tables -A FORWARD -i ${iiface} -o ${oiface} -j ACCEPT"
                      ] else [ ]
                    )
                    interfaceNames
                )
              )
              interfaceNames
          )
        );
        extraStopCommands = concatStringsSep "\n" (
          flatten (
            map
              (
                iiface: (
                  map
                    (
                      oiface:
                      if iiface != oiface then [
                        "iptables -D FORWARD -i ${iiface} -o ${oiface} -j ACCEPT || :"
                        "ip6tables -D FORWARD -i ${iiface} -o ${oiface} -j ACCEPT || :"
                      ] else [ ]
                    )
                    interfaceNames
                )
              )
              interfaceNames
          )
        );
      };

      h4ck.wireguardBackbone.peers = mapAttrs'
        (
          name: value: nameValuePair "dn42_${name}" (
            {
              inherit (value.wireguardConfig) localPort remoteEndpoint remotePort remotePublicKey;
              remoteAddresses = (optional (value.addresses.ipv6 != null && value.addresses.ipv6 ? remote_address) value.addresses.ipv6.remote_address)
              ++ (optional (value.addresses.ipv4 != null && value.addresses.ipv4 ? remote_address) value.addresses.ipv4.remote_address);
              localAddresses = optional (value.addresses.ipv6 != null && value.addresses.ipv6 ? local_address)
                (
                  if (value.addresses.ipv6.prefix_length != 128) then
                    "${value.addresses.ipv6.local_address}/${toString value.addresses.ipv6.prefix_length}"
                  else
                    {
                      local = "${value.addresses.ipv6.local_address}/128";
                      peer = "${toString value.addresses.ipv6.remote_address}/128";
                    }
                )
              ++ (optional (value.addresses.ipv4 != null && value.addresses.ipv4 ? local_address) "${value.addresses.ipv4.local_address}/${toString value.addresses.ipv4.prefix_length}");
            } // optionalAttrs (value.mtu != null) {
              inherit (value) mtu;
            }
          )
        )
        wireguardPeers;

      services.bird2.config = ''
                #
                # DN42 peering configuration
                #

                ipv4 table dn42_v4;
                ipv6 table dn42_v6;

                ${optionalString (interfaceNames != [ ]) ''
                protocol direct dn42_direct {
                  interface ${concatMapStringsSep ", " (iface: "\"${iface}\"") interfaceNames};
                }
              ''}

                protocol static dn42_static_v4 {
                  ipv4 { table dn42_v4; };
                  route 172.20.0.0/14 blackhole; # summary route so we only route traffic where we have more specifics
                  ${concatMapStringsSep "\n" (net: "route ${net} blackhole;") cfg.bgp.staticRoutes.ipv4}
                };

                protocol static dn42_static_v6 {
                  ipv6 { table dn42_v6; };
                  route fd00::/8 blackhole; # summary route so we only route traffic where we have more specifics
                  ${concatMapStringsSep "\n" (net: "route ${net} blackhole;") cfg.bgp.staticRoutes.ipv6}
                };

                function dn42_is_valid_prefix (prefix n) {
                  case n.type {
                    NET_IP4: if n ~ [
                             172.20.0.0/14{21,29}, # dn42
                             172.20.0.0/24{28,32}, # dn42 Anycast
                             172.21.0.0/24{28,32}, # dn42 Anycast
                             172.22.0.0/24{28,32}, # dn42 Anycast
                             172.23.0.0/24{28,32}, # dn42 Anycast
                             #172.31.0.0/16+,       # ChaosVPN
                             #10.100.0.0/14+,       # ChaosVPN
                             #10.127.0.0/16{16,32}, # neonetwork
                             10.0.0.0/8{15,24}     # Freifunk.net
                          ] then return true;
                    NET_IP6: if n ~ [ fd00::/8{40,64} ] then return true;
                  }
                  return false;
                }

                function dn42_is_own_prefix(prefix n) {
                  case n.type {
                    NET_IP4: if n ~ [ ${concatMapStringsSep ",\n" (net: "${net}+") cfg.bgp.staticRoutes.ipv4} ] then return true;
                    NET_IP6: if n ~ [ ${concatMapStringsSep ",\n" (net: "${net}+") cfg.bgp.staticRoutes.ipv6} ] then return true;
                  }
                  return false;
                }

                roa4 table dn42_roa_v4;
                roa6 table dn42_roa_v6;

                protocol static {
                  roa4 { table dn42_roa_v4; };
                  include "${pkgs.dn42-roa.roa4}";
                };

                protocol static {
                  roa6 { table dn42_roa_v6; };
                  include "${pkgs.dn42-roa.roa6}";
                };

                function dn42_roa_check(prefix n; bgppath p) {
                   case n.type {
                     NET_IP4: return (roa_check(dn42_roa_v4, net, p.last) = ROA_VALID);
                     NET_IP6: return (roa_check(dn42_roa_v6, net, p.last) = ROA_VALID);
                   }
                   return false;
                }

                protocol pipe dn42_v4_pipe {
                  peer table master4;
                  table dn42_v4;
                  export filter {
                    ${lib.optionalString cfg.srcpref.v4Address != null ''
                      krt_prefsrc = ${cfg.srcpref.v4Address}
                    ''}
                    accept;
                  };
                  import none;
                }

                protocol pipe dn42_v6_pipe {
                  peer table master6;
                  table dn42_v6;
                  export filter {
                    ${lib.optionalString cfg.srcpref.v6Address != null ''
                      krt_prefsrc = ${cfg.srcpref.v6Address}
                    ''}
                    accept;
                  };
                  import none;
                }

                ${lib.concatMapStringsSep "\n\n"
        (
                peer: ''
                  #
                  # Peer: ${peer.name}
                  # Remote ASN: ${toString peer.bgp.asn}
                  #

                  filter dn42_${peer.name}_import {
                     ${optionalString peer.bgp.import_reject "reject \"rejecting all import prefixes\";"}
                     if !dn42_is_valid_prefix(net) then {
                       ${lib.optionalString cfg.enableDebugLogging ''
                         print "Not a valid DN42 prefix from asn ${toString peer.bgp.asn} net:" , net, " bgp_path: ", bgp_path;
                       ''}
                       reject${lib.optionalString cfg.enableDebugLogging '' "Not a valid dn42 prefix"''};
                      }
                     ${optionalString (peer.bgp.asn != cfg.bgp.asn)
                  # eBGP isn't allowed to annouce me my own prefixes
                  ''

                    if bgp_path.first != ${toString peer.bgp.asn} then reject "Not accepting spoofed AS path";

                    ${optionalString (peer.bgp.accept == "own") ''
                    if delete(bgp_path, [${toString peer.bgp.asn}]).len > 0 then {
                      ${lib.optionalString cfg.enableDebugLogging ''
                        print "rejecting prefix that isn't from the peer asn ${toString peer.bgp.asn}", " net: ", net, " bgp_path: ", bgp_path;
                      ''}
                      reject${lib.optionalString cfg.enableDebugLogging '' "Not from peer ASN";''};
                    }
                    #if bgp_path.len > 1 && bgp_path.last != bgp_path.first then reject "Only accepting paths originating at the peer as";
                  ''}

                    if dn42_is_own_prefix(net) then reject "Not accepting own prefix from eBGP peer.";
                    if filter(bgp_path, [${toString cfg.bgp.asn}]).len > 0 then {
                        ${lib.optionalString cfg.enableDebugLogging ''
                          print "Not accepting paths from my own ASN via eBGP from asn: ${toString peer.bgp.asn} net: ", net, " bgp_path: ", bgp_path;
                        ''}
                         reject${lib.optionalString cfg.enableDebugLogging '' "Not accepting my own path via eBGP"''};
                    }
                    if !dn42_roa_check(net, bgp_path) then {
                      printn "DN42 ROA check failed for ", net;
                      reject "DN42 ROA check failed";
                    }

                    ${optionalString (peer.bgp.import_prepend != 0)
                    (concatStrings (map (x: "bgp_path.prepend(${toString cfg.bgp.asn});\n") (range 0 peer.bgp.import_prepend)))}

                    bgp_local_pref = ${toString peer.bgp.local_pref};

                  ''}
                     accept;
                  }
                  filter dn42_${peer.name}_export {
                    ${optionalString peer.bgp.export_reject "reject \"rejecting all export prefixes\";"}

                    # only propagate static and BGP routes.
                    if source != RTS_STATIC && source != RTS_BGP then reject${lib.optionalString cfg.enableDebugLogging '' "invalid route source"''};

                    ${optionalString (peer.bgp.asn != cfg.bgp.asn && peer.bgp.announce == "own") ''
                    if source != RTS_STATIC && delete(bgp_path, [${toString cfg.bgp.asn}]).len > 0 then {
                    ${lib.optionalString cfg.enableDebugLogging ''
                      printn "Only propagating own routes. net: ", net, " source: ", source, " path: ", bgp_path, " deleted path: ", delete(bgp_path, [${toString cfg.bgp.asn}]);
                    ''}
                    reject${lib.optionalString cfg.enableDebugLogging '' "Not one of my routes"''};
                  }
                ''}

                    if !dn42_is_valid_prefix(net) then reject "Not a valid DN42 prefix";
                    if proto !~ "dn42_*" then reject "Prefix is not from another dn42 protocol. Rejecting.";
                    ${optionalString (peer.bgp.export_prepend != 0)
                  (concatStrings (map (x: "bgp_path.prepend(${toString cfg.bgp.asn});\n") (range 0 peer.bgp.export_prepend)))}
                    if source = RTS_BGP && !dn42_roa_check(net, bgp_path) && bgp_path.len > 0 then {
                      ${lib.optionalString cfg.enableDebugLogging ''
                        printn "DN42 ROA check failed for ", net;
                      ''}
                      reject${lib.optionalString cfg.enableDebugLogging '' "DN42 ROA check failed";''};
                        } else if source = RTS_BGP && bgp_path.len = 0 && !dn42_roa_check(net, prepend(bgp_path, ${toString cfg.bgp.asn})) then {
                      ${lib.optionalString cfg.enableDebugLogging ''
                        printn "DN42 ROA check failed for our net ", net;
                      ''}
                      reject${lib.optionalString cfg.enableDebugLogging '' "Refusing to announce (our) prefix that isn't covered by a valid ROA"''};
                    }

                    accept;
                  }

                  template bgp dn42_${peer.name}_tpl {
                    local as ${toString cfg.bgp.asn};
                    graceful restart on;
                    graceful restart time 120;
                    interpret communities on;
                    enable extended messages on;
                    enable route refresh on;
                    med metric on;
                    direct;
                    #advertise ipv4 on;

                    ipv4 {
                      import table on;
                      export table on;
                      gateway recursive;
                      table dn42_v4;
                      igp table master4;
                      add paths on;
                      import filter dn42_${peer.name}_import;
                      export filter dn42_${peer.name}_export;
                      import keep filtered on;
                      ${lib.optionalString (peer.bgp.asn != cfg.bgp.asn) ''
                        next hop self on;
                      ''}
                      ${optionalString (peer.bgp.import_limit != null) "import limit ${toString peer.bgp.import_limit} action block;"}
                    };
                    ipv6 {
                      import table on;
                      export table on;
                      table dn42_v6;
                      igp table master6;
                      add paths on;
                      import filter dn42_${peer.name}_import;
                      export filter dn42_${peer.name}_export;
                      import keep filtered on;
                      ${lib.optionalString (peer.bgp.asn != cfg.bgp.asn) ''
                        next hop self on;
                      ''}
                      ${optionalString (peer.bgp.import_limit != null) "import limit ${toString peer.bgp.import_limit} action block;"}
                    };
                  }

                  ${if peer.bgp.multi_protocol then ''
                  protocol bgp dn42_${peer.name} from dn42_${peer.name}_tpl {
                    neighbor ${peer.remoteV6} as ${toString peer.bgp.asn};
                    interface "${peer.interfaceName}";
                  };
                '' else ''
                  protocol bgp dn42_${peer.name}_v4 from dn42_${peer.name}_tpl {
                    neighbor ${peer.remoteV4} as ${toString peer.bgp.asn};
                    interface "${peer.interfaceName}";
                  }
                  protocol bgp dn42_${peer.name}_v6 from dn42_${peer.name}_tpl {
                    #advertise ipv4 off;
                    neighbor ${peer.remoteV6} as ${toString peer.bgp.asn};
                    ${optionalString (hasPrefix "fe80:" peer.remoteV6) ''
                  interface "${peer.interfaceName}";
                ''}
                  }
                ''}
                ''
              )
        bgpPeers}
      '';
    };
}
