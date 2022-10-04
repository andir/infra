{ src
, npmlock2nix
, coreutils
, stdenv
, fetchurl
, fetchzip
, runCommand
, buildGo118Module
, libtensorflow-bin
, nodejs-14_x
, callPackage
}:
buildGo118Module {
  name = "photoprism";
  inherit src;

  subPackages = [ "cmd/photoprism" ];

  buildInputs = [
    (libtensorflow-bin.overrideAttrs (oA: {
      # 21.05 does not have libtensorflow-bin 1.x anymore & photoprism isn't compatible with tensorflow 2.x yet
      # https://github.com/photoprism/photoprism/issues/222
      src = fetchurl {
        url = "https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-1.14.0.tar.gz";
        sha256 = "04bi3ijq4sbb8c5vk964zlv0j9mrjnzzxd9q9knq3h273nc1a36k";
      };
    }))
  ];

  prePatch = ''
    substituteInPlace internal/commands/passwd.go --replace '/bin/stty' "${coreutils}/bin/stty"
  '';
  vendorSha256 = "1cvwhgqy49pxxypywg9gnjvisnb0dqjmzpi1nywh9afj13aivmvq";

  # https://github.com/mattn/go-sqlite3/issues/803
  CGO_CFLAGS = "-Wno-return-local-addr";

  postInstall = ''
    $out/bin/photoprism --help 
  '';


  passthru = rec {
    frontend = npmlock2nix.v2.build {
      src = src + "/frontend";
      buildCommands = [
        "HOME=$(mktemp -d) npm run build"
      ];
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

        facenet = fetchzip {
          url = "https://dl.photoprism.org/tensorflow/facenet.zip";
          sha256 = "0vyfy7hidlzibm59236ipaymj0mzclnriv9bi86dab1sa627cqpd";
        };
      in
      runCommand "photoprims-assets" { } ''
        cp -rv ${src}/assets $out
        chmod -R +rw $out
        rm -rf $out/static/build
        cp -rv ${frontend} $out/static/build
        ln -s ${nsfw} $out/nsfw
        ln -s ${nasnet} $out/nasnet
        ln -s ${facenet} $out/facenet
      '';
  };
}
