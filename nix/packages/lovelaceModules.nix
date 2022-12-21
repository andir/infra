{ lib, sources, callPackage, runCommand, writeText }:
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
    ({ runCommand }: runCommand "lovelace-rmv-card"
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

  multiple-entity-row = callPackage
    ({ runCommand }: runCommand "lovelace-multiple-entity-row"
      {
        src = sources.lovelace-multiple-entity-row;
        passthru.files = [
          "${multiple-entity-row}/multiple-entity-row.js"
        ];
      } ''
      mkdir $out
      cp $src/multiple-entity-row.js $out
    '')
    { };

  mini-media-player = callPackage
    ({ npmlock2nix, nodejs-18_x }: npmlock2nix.v2.build {
      src = sources.lovelace-mini-media-player;
      nodejs = nodejs-18_x;
      passthru.files = [
        "${mini-media-player}/dist.js"
      ];
      buildCommands = [
        "npm run build"
      ];
      installPhase = ''
        mkdir $out
        cp dist/mini-media-player-bundle.js $out/dist.js
      '';
    })
    { };

  mini-graph-card = callPackage
    ({ npmlock2nix, nodejs-18_x }: npmlock2nix.v2.build {
      src = sources.lovelace-mini-graph-card;
      nodejs = nodejs-18_x;
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

  battery-state-card = callPackage
    ({ npmlock2nix, nodejs-18_x }: npmlock2nix.v2.build {
      src = sources.lovelace-battery-state-card;
      nodejs = nodejs-18_x;
      passthru.files = [
        "${battery-state-card}/dist.js"
      ];
      buildCommands = [
        "npm run release"
      ];
      installPhase = ''
        mkdir $out
        cp dist/battery-state-card.js $out/dist.js
      '';
    })
    { };

  auto-entities = callPackage
    ({ runCommand }: runCommand "lovelace-auto-entities"
      {
        src = sources.lovelace-auto-entities;
        passthru.files = [
          "${auto-entities}/dist.js"
        ];
      } ''
      mkdir $out
      cp $src/auto-entities.js $out/dist.js
    '')
    { };


  vacuum-card = callPackage
    ({ npmlock2nix, nodejs-18_x }:
      let
        babelRcPatch = writeText "babel.patch" ''
          From 8e58a3479365536dfd61d4d228a6d03b9cd6af17 Mon Sep 17 00:00:00 2001
          From: Andreas Rammhold <andreas@rammhold.de>
          Date: Wed, 14 Dec 2022 13:57:25 +0100
          Subject: [PATCH] Use bablerc in rollup.config.js

          ---
           rollup.config.js | 9 +++++++--
           1 file changed, 7 insertions(+), 2 deletions(-)

          diff --git a/rollup.config.js b/rollup.config.js
          index fd661b1..8067fa8 100755
          --- a/rollup.config.js
          +++ b/rollup.config.js
          @@ -2,7 +2,7 @@
           import commonjs from '@rollup/plugin-commonjs';
           import nodeResolve from '@rollup/plugin-node-resolve';
           import json from '@rollup/plugin-json';
          -import babel from '@rollup/plugin-babel';
          +import babel, { getBabelOutputPlugin } from '@rollup/plugin-babel';
           import image from '@rollup/plugin-image';
           import postcss from 'rollup-plugin-postcss';
           import postcssPresetEnv from 'postcss-preset-env';
          @@ -33,9 +33,14 @@ export default {
               nodeResolve(),
               commonjs(),
               json(),
          +    // getBabelOutputPlugin({
          +    //   configFile: path.resolve(__dirname, '.babelrc'),
          +    //   allowAllFormats: true,
          +    // }),
               babel({
                 babelHelpers: 'runtime',
          -      exclude: 'node_modules/**',
          +      exclude: /^(.+\/)?node_modules\/.+$/,
          +      skipPreflightCheck: 'true',
               }),
               postcss({
                 plugins: [
          -- 
          2.38.1
        '';
      in
      npmlock2nix.v2.build {
        src = sources.vacuum-card;
        nodejs = nodejs-18_x;
        passthru.files = [
          "${vacuum-card}/vacuum-card.js"
        ];
        patches = [ babelRcPatch ];
        node_modules_attrs = {
          preBuild = ''
            sed -e 's;husky install;true;g' -i package.json
          '';
        };
        buildCommands = [
          "npm run build"
        ];
        installPhase = ''
          mkdir $out
          cp dist/vacuum-card.js $out/vacuum-card.js
        '';
      })
    { };

  allResources = mkResources [
    rmv-card
    mini-media-player
    mini-graph-card
    vacuum-card
    multiple-entity-row
    battery-state-card
    auto-entities
  ];
}
