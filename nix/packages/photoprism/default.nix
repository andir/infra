{ src
, npmlock2nix
, coreutils
, stdenv
, fetchurl
, fetchzip
, runCommand
, buildGo119Module
, my-libtensorflow-bin
, nodejs-18_x
, callPackage
}:
buildGo119Module {
  name = "photoprism-go";
  inherit src;

  subPackages = [ "cmd/photoprism" ];

  buildInputs = [
    my-libtensorflow-bin
  ];

  prePatch = ''
    substituteInPlace internal/commands/passwd.go --replace '/bin/stty' "${coreutils}/bin/stty"
  '';
  vendorSha256 = "sha256-PUUV+PdPAfntb3s9cKd8T+hnW9xiUTBDmQmTzT1+tTw=";

  # https://github.com/mattn/go-sqlite3/issues/802
  CGO_CFLAGS = "-Wno-return-local-addr";

  postInstall = ''
    $out/bin/photoprism --help
  '';


  passthru = rec {
    frontend = npmlock2nix.v2.build {
      nodejs = nodejs-18_x;
      src = src + "/frontend";
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
