{ src
, ranz2nix
, coreutils
, stdenv
, fetchurl
, fetchzip
, runCommand
, buildGoModule
, libtensorflow-bin
, nodejs-14_x
, callPackage
}:
buildGoModule {
  name = "photoprism-go";
  inherit src;

  goPackagePath = "github.com/photoprism/photoprism";
  subPackages = [ "cmd/photoprism" ];

  buildInputs = [ libtensorflow-bin ];

  prePatch = ''
    substituteInPlace internal/commands/passwd.go --replace '/bin/stty' "${coreutils}/bin/stty"
    sed -i 's/zip.Deflate/zip.Store/g' internal/api/zip.go
  '';

  vendorSha256 = "18vknfmyqddd2213rm2n097l1y3p62w1z76mlgkcqfi2d3dyrarr";

  passthru = rec {

    frontend =
      let
        noderanz = callPackage ranz2nix {
          nodejs = nodejs-14_x;
          sourcePath = src + "/frontend";
          packageOverride = name: spec:
            if name == "minimist" && spec ? resolved && spec.resolved == "" && spec.version == "1.2.0" then {
              resolved = "file://" + (
                toString (
                  fetchurl {
                    url = "https://registry.npmjs.org/minimist/-/minimist-1.2.0.tgz";
                    sha256 = "0w7jll4vlqphxgk9qjbdjh3ni18lkrlfaqgsm7p14xl3f7ghn3gc";
                  }
                )
              );
            } else { };
        };
        node_modules = noderanz.patchedBuild;
      in
      stdenv.mkDerivation {
        name = "photoprism-frontend";
        nativeBuildInputs = [ nodejs-14_x ];

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

    assets =
      let
        nasnet = fetchzip {
          url = "https://dl.photoprism.org/tensorflow/nasnet.zip";
          sha256 = "09cnr2wpc09xrv1crms3mfcl61rxf4nr5j51ppy4ng6bxg9rq5s1";
        };

        nsfw = fetchzip {
          url = "https://dl.photoprism.org/tensorflow/nsfw.zip";
          sha256 = "0j0r39cgrr0zf2sc1hpr8jh19lr3jxdw9wz6sq3s7kkqay324ab8";
        };

      in
      runCommand "photoprims-assets" { } ''
        cp -rv ${src}/assets $out
        chmod -R +rw $out
        rm -rf $out/static/build
        cp -rv ${frontend} $out/static/build
        ln -s ${nsfw} $out/nsfw
        ln -s ${nasnet} $out/nasnet
      '';
  };
}
