{ name, config, nodes, lib, ... }:
let
  currentNodeName = name;
  wireLib = import ./lib.nix { inherit lib; };

  cfg = config.h4ck.wireguard;

  # mkPeer :: String -> AttrSet
  # generate the peer configuration for one single peer
  mkPeer = selfName: peerName:
    assert builtins.isString selfName;
    assert builtins.isString peerName;
    let
      port = with (
        if selfName < peerName then {
          a = selfName;
          b = peerName;
        } else {
          a = peerName;
          b = selfName;
        }
      );

        wireLib.genPort 15000 16000 a b;

      peerConfig = cfg.hosts.${peerName};
      selfConfig = cfg.hosts.${selfName};
    in
    {
      babel = lib.mkDefault true;
      remoteEndpoint = lib.mkDefault
        (
          if peerConfig ? hostName then
            peerConfig.hostName
          else nodes.${peerName}.config.h4ck.fqdn
        );
      remotePort = lib.mkDefault port;
      localPort = lib.mkDefault port;
      localAddresses = lib.mkDefault selfConfig.addresses;
      remoteAddresses = lib.mkDefault peerConfig.addresses;
      remotePublicKey = lib.mkDefault peerConfig.publicKey;
    };

  mkConfig = hostName:
    # generate the wireguard configuration for the given hostname based on the configuration in
    # cfg.hosts
    let
      mesh = wireLib.mesh { servers = cfg.hosts; };
    in
    if mesh ? ${hostName} then
      lib.filterAttrs (k: _: ! builtins.elem k [ "hostName" "connections" ])
        (
          mesh.${hostName} // {
            peers = builtins.listToAttrs (
              map
                (peer: lib.nameValuePair peer (mkPeer hostName peer))
                mesh.${hostName}.connections
            );
          }
        )
    else { };
  loopbackAddresses = lib.attrByPath [ "hosts" currentNodeName "loopbackAddresses" ] null cfg;

  firstV4Net = lib.head (lib.filter (addr: ! (builtins.elem ":" (builtins.split "" addr))) loopbackAddresses);
  firstV4Address = lib.head (builtins.split "/" firstV4Net);

  firstV6Net = lib.head (lib.filter (addr: (builtins.elem ":" (builtins.split "" addr))) loopbackAddresses);
  firstV6Address = lib.head (builtins.split "/" firstV6Net);

in
{
  # executed in the context of a single node

  options.h4ck.wireguard.hosts = lib.mkOption {
    type = lib.types.attrs;
    default = { };
  };
  config.h4ck.wireguardBackbone = mkConfig currentNodeName;
  config.systemd.network = lib.mkIf (loopbackAddresses != null && loopbackAddresses != [ ]) {
    netdevs = {
      "40-wireguard-loopback" = {
        netdevConfig = {
          Name = "wg-loopback";
          Kind = "dummy";
        };
      };
    };
    networks = {
      "40-wireguard-loopback" = {
        matchConfig = {
          Name = "wg-loopback";
        };
        addresses = map (a: { addressConfig.Address = a; }) loopbackAddresses;
      };
    };
  };
  config.h4ck.bird =
    let
    in
    lib.mkIf (loopbackAddresses != null && loopbackAddresses != [ ]) {
      routerId = lib.mkDefault firstV4Address;
      srcpref = {
        v4Address = firstV4Address;
        v6Address = firstV6Address;
      };
    };
}
