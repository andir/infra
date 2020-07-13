{ src
, ranz2nix
, stdenv
, fetchurl
, fetchzip
, runCommand
, buildGoModule
, python3Packages
, nodejs-12_x
, callPackage
}:
buildGoModule {
  name = "test";
  inherit src;

  goPackagePath = "github.com/photoprism/photoprism";
  subPackages = [ "cmd/photoprism" ];

  buildInputs = [ python3Packages.tensorflow.libtensorflow ];

  vendorSha256 = "1g1vycmgcr4a6d255ll6mmdc9qndpyvqxc02ahg0jkpfk1p2y8nh";

  passthru = rec {

    frontend = let
      noderanz = callPackage ranz2nix {
        nodejs = nodejs-12_x;
        sourcePath = src + "/frontend";
        packageOverride = name: spec: if name == "minimist" && spec ? resolved && spec.resolved == "" then {
          resolved = "file://" + (
            toString (
              fetchurl {
                url = "https://registry.npmjs.org/minimist/-/minimist-1.2.0.tgz";
                sha256 = "0w7jll4vlqphxgk9qjbdjh3ni18lkrlfaqgsm7p14xl3f7ghn3gc";
              }
            )
          );
        } else {};
      };
      node_modules = noderanz.patchedBuild;
    in
      stdenv.mkDerivation {
        name = "photoprism-frontend";
        nativeBuildInputs = [ nodejs-12_x ];

        inherit src;

        sourceRoot = "photoprism-src/frontend";

        postUnpack = ''
          chmod -R +rw .
        '';

        NODE_ENV = "production";

        buildPhase = ''
          export HOME=$(mktemp -d)
          ln -sf ${node_modules}/node_modules node_modules
          ln -sf ${node_modules.lockFile} package-lock.json
          npm run build
        '';
        installPhase = ''
          cp -rv ../assets/static/build $out
        '';
      };

    assets = let
      nasnet = fetchzip {
        url = "https://dl.photoprism.org/tensorflow/nasnet.zip";
        sha256 = "09cnr2wpc09xrv1crms3mfcl61rxf4nr5j51ppy4ng6bxg9rq5s1";
      };

      nsfw = fetchzip {
        url = "https://dl.photoprism.org/tensorflow/nsfw.zip";
        sha256 = "0j0r39cgrr0zf2sc1hpr8jh19lr3jxdw9wz6sq3s7kkqay324ab8";
      };

    in
      runCommand "photoprims-assets" {} ''
        cp -rv ${src}/assets $out
        chmod -R +rw $out
        rm -rf $out/static/build
        cp -rv ${frontend} $out/static/build
        ln -s ${nsfw} $out/nsfw
        ln -s ${nasnet} $out/nasnet
      '';
  };
}
