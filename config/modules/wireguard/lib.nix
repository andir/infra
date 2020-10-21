{ lib ? (import <nixpkgs> { }).lib }:
let
  # sort :: [ T ] -> [ T ]
  sort = lib.sort (a: b: a < b);


  # generateNeighbours :: { name :: String, server :: AttrSet, servers :: AttrSet } -> [ String ]
  # generate the mesh set of a single server
  generateNeighbours = { name, server, servers }:
    assert !builtins.isString name -> builtins.throw "`name` should be a string, got ${builtins.typeOf name}";
    assert !builtins.isAttrs server -> builtins.throw "`server` should be an attribute set, get ${builtins.typeOf servers}";
    assert !builtins.isAttrs servers -> builtins.throw "`servers` should be an attribute set, get ${builtins.typeOf servers}";
    assert server ? connection -> !builtins.isList server.connections -> builtins.throw "`server.connections` should be a list";
    sort (
      lib.attrNames (
        lib.filterAttrs
          (
            peerName: peer:

              # do not connect to self
              (peerName != name)
              && # if server.connections is set only connect to those
              (if server ? connections then builtins.elem peerName server.connections else true)
              && # if peer.connections is set only connect to those
              (if peer ? connections then builtins.elem name peer.connections else true)

          )
          servers
      )
    );

  md5ToInt = str:
    let
      toToml = s: "x = 0x${builtins.substring 0 15 s}";
    in
    (builtins.fromTOML (toToml str)).x;
  mod = n: m:
    n - ((builtins.div n m) * m);
in
{
  inherit mod;

  mesh = { servers }:
    assert !builtins.isAttrs servers -> builtins.throw "`servers` should be an attribute set, got ${builtins.typeOf servers}";

    lib.mapAttrs
      (
        name: server: {
          connections = generateNeighbours { inherit name server servers; };
        }
      )
      servers;

  genPort = minPort: maxPort: serverA: serverB:
    assert !builtins.isString serverA -> builtins.throw "`serverA` should be a string, got ${builtins.typeOf serverA}";
    assert !builtins.isString serverB -> builtins.throw "`serverB` should be a string, got ${builtins.typeOf serverB}";
    let
      width = maxPort - minPort;
    in
    assert width <= 0 -> builtins.throw "maxPort - minPort must be >= 1";

    minPort + (mod ((md5ToInt (builtins.hashString "md5" serverA)) + (md5ToInt (builtins.hashString "md5" serverB))) width);

}
