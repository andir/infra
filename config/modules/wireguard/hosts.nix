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
    in
      {
        babel = lib.mkDefault true;
        remoteEndpoint = lib.mkDefault
          (
            if peerConfig ? hostName then
              peerConfig.hostName
            else nodes.${peerName}.config.networking.hostName
          );
        remotePort = lib.mkDefault port;
        localPort = lib.mkDefault port;
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
        lib.filterAttrs (k: _: ! builtins.elem k [ "hostName" "connections" ]) (
          mesh.${hostName} // {
            peers = builtins.listToAttrs (
              map
                (peer: lib.nameValuePair peer (mkPeer hostName peer))
                mesh.${hostName}.connections
            );
          }
        )
      else {};
in
{
  # executed in the context of a single node

  options.h4ck.wireguard.hosts = lib.mkOption {
    type = lib.types.attrs;
  };
  config.h4ck.wireguardBackbone = mkConfig currentNodeName;
}
