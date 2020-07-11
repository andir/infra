{ src
, stdenv
, fetchzip
, runCommand
, buildGoModule
, python3Packages
, nodejs-12_x
}:
buildGoModule {
  name = "test";
  inherit src;

  goPackagePath = "github.com/photoprism/photoprism";
  subPackages = [ "cmd/photoprism" ];

  buildInputs = [ python3Packages.tensorflow.libtensorflow ];

  vendorSha256 = "1g1vycmgcr4a6d255ll6mmdc9qndpyvqxc02ahg0jkpfk1p2y8nh";

  passthru = rec {

    frontend =
      stdenv.mkDerivation {
        name = "photoprism-frontend";
        nativeBuildInputs = [ nodejs-12_x ];
        outputHash = "0wwizcfcr4dzzjrww0apzgq7hnhgavbii7wwwdi8ab16gn8m1jmn";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        inherit src;

        HOME = "/tmp";
        NODE_ENV = "production";

        sourceRoot = "photoprism-src/frontend";

        postUnpack = ''
          chmod -R +rw .
        '';

        buildPhase = ''
          npm install
          patchShebangs node_modules
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
