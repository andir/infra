{ config, lib, ... }:
let
  cfg = config.h4ck;
in
{
  options.h4ck = {
    disableSlipstreamConntrackModules = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable some low-bar mitigation for the NAT Slipstream attack (https://samy.pl/slipstream/#live-browser-packet-alteration)
        by disabling some ALGs (Application Level Gateways) that Linux provides.
      '';
    };
  };
  config = lib.mkIf cfg.disableSlipstreamConntrackModules {
    boot.blacklistedKernelModules = [
      # find /run/current-system/kernel-modules/lib/modules/*/kernel/ -type f -iname 'nf_conntrack_*' -print0 | \ xargs -0 -n1 basename | sed -e 's/\.ko\.xz//g' -e 's/^/"/' -e 's/$/"/'
      "nf_conntrack_irc"
      "nf_conntrack_sane"
      "nf_conntrack_netbios_ns"
      "nf_conntrack_pptp"
      "nf_conntrack_h323"
      "nf_conntrack_snmp"
      "nf_conntrack_tftp"
      "nf_conntrack_netlink"
      "nf_conntrack_amanda"
      "nf_conntrack_broadcast"
      "nf_conntrack_ftp"
      "nf_conntrack_sip"
      "nf_conntrack_bridge"
    ];
  };
}
