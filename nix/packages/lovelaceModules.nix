{ lib, sources, callPackage, runCommand }:
let
  mkResources = packages:
    let
      hashPath = file: (builtins.hashString "sha1" (toString file)) + ".js";
      files = lib.flatten (map (p: p.files or [ ]) packages);
      namedFiles = lib.listToAttrs (map (file: lib.nameValuePair (hashPath file) file) files);
      wwwRootCommand = name: file: "cp ${file} ${name}";
      wwwRootCommands = lib.mapAttrsToList wwwRootCommand namedFiles;
    in
    {
      resources = map
        (name: {
          url = "/nix-resources/" + name;
          type = "module";
        })
        (lib.attrNames namedFiles);
      wwwRoot = runCommand "www-root" { }
        (''
          mkdir $out
          cd $out
        ''
        + lib.concatStringsSep "\n" wwwRootCommands);
    };
in
rec {
  rmv-card = callPackage
    ({ runCommand }: runCommand "lovelance-rmv-card"
      {
        src = sources.lovelance-rmv-card;

        passthru.files = [
          "${rmv-card}/rmv-card.js"
        ];
      } ''
      mkdir $out
      cp $src/rmv-card.js $out/rmv-card.js
    '')
    { };

  mini-media-player = callPackage
    ({ npmlock2nix, nodejs-14_x }: npmlock2nix.build {
      src = sources.lovelace-mini-media-player;
      nodejs = nodejs-14_x;
      passthru.files = [
        "${mini-media-player}/dist.js"
      ];
      buildCommands = [
        "npm run build"
        "npm run babel"
      ];
      installPhase = ''
        mkdir $out
        cp dist/mini-media-player-bundle.js $out/dist.js
      '';
    })
    { };

  mini-graph-card = callPackage
    ({ npmlock2nix, nodejs-14_x }: npmlock2nix.build {
      src = sources.lovelace-mini-graph-card;
      nodejs = nodejs-14_x;
      passthru.files = [
        "${mini-graph-card}/dist.js"
      ];
      buildCommands = [
        "npm run build"
        "npm run babel"
      ];
      installPhase = ''
        mkdir $out
        cp dist/mini-graph-card-bundle.js $out/dist.js
      '';
    })
    { };

  allResources = mkResources [
    rmv-card
    mini-media-player
    mini-graph-card
  ];
}
