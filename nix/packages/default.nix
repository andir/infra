{ sources, system, config }:
let
  unstable = import sources.nixpkgs-unstable { inherit system config; };
in
self: super: {
  inherit sources unstable;

  ate = self.callPackage sources.ate { };

  # systemd variant that fixes my weird netlink message issue on bootup
  # on machines that have more than just one or two wireguard interfaces.
  # See https://github.com/systemd/systemd/issues/17232 for details.
  systemd-boot =
    let
      applyPatch = super.lib.versionOlder super.systemd.version "247.6";
      updateSource = super.lib.versionOlder super.systemd.version "247";
    in
    super.systemd.overrideAttrs ({ patches, ... }:
      (if updateSource then {
        src = super.fetchFromGitHub {
          owner = "systemd";
          repo = "systemd-stable";
          rev = "v246.10";
          sha256 = "0llm288g18zsidd7rasan3cah46432xdj74caqm6ia8lpvrxbvh8";
        };
      } else { })
      // (if applyPatch then {
        patches = patches ++ [
          ./18545.patch
        ];
      } else { })
    );

  knot_exporter = self.callPackage ./knot_exporter.nix {
    src = sources.knot_exporter;
  };
  prometheus-xmpp-alerts = self.callPackage ./prometheus-xmpp-alerts.nix { };
  grafanaPlugins = {
    statusmap = super.fetchFromGitHub {
      owner = "flant";
      repo = "grafana-statusmap";
      rev = "v0.2.0";
      sha256 = "1franflr7xci8zdcd5qmqxxalnimjpz2yyhpa51la5d16mnmch9r";
    };
  };

  conversejs = super.callPackage ./conversejs { };

  morph = (unstable.callPackage (sources.morph + "/default.nix") { }).overrideAttrs (
    _: {
      patches = [ ./morph-evalConfig-machinename.patch ];
    }
  );

  bird2 = super.enableDebugging (super.bird2.overrideAttrs (
    { patches ? [ ], configureFlags ? [ ], nativeBuildInputs ? [ ], ... }: {

      #configureFlags = configureFlags ++ [ "--enable-debug" ];
      nativeBuildInputs = nativeBuildInputs ++ [ super.autoreconfHook ];
      src = super.fetchgit {
        url = "https://git.sr.ht/~andir/bird";
        rev = "01dba342cdb52bed4b244eb304269609dae3a423";
        sha256 = "0hhx7zhri67sw83vwvq0zkhvl56h9m7spjw69lfgg087p3acy7xd";
      };
      patches = patches ++ [ ./bird-next-hop-logging.patch ];
    }
  ));

  dn42-regparse = self.callPackage sources.dn42-regparse { };
  dn42-roa =
    let
      roa = self.runCommand "dn42-roa"
        {
          buildInputs = [ self.dn42-regparse ];
          passthru = {
            roa4 = "${roa}/roa.txt";
            roa6 = "${roa}/roa6.txt";
          };
        } ''
        mkdir $out
        cd $out
        roagen ${sources.dn42-registry}/data
      '';
    in
    roa;

  coturn = super.coturn.overrideAttrs (
    { buildInputs, ... }: {
      buildInputs = buildInputs ++ [ self.sqlite ];
    }
  );

  photoprism = self.callPackage ./photoprism {
    src = sources.photoprism;
    ranz2nix = sources.ranz2nix;
  };

  fping_exporter = self.callPackage ./fping-exporter.nix { };

  rockpi4 = self.callPackage ./rockpi4 { };

  lego = super.lego.overrideAttrs (_: {
    patches = [
      ./lego-retry.diff
    ];
  });

  python3 = super.python3.override {
    packageOverrides = _: psuper: {
      psautohint = psuper.psautohint.overridePythonAttrs (_: { doCheck = false; });
    };
  };

  dendrite = unstable.buildGoModule {
    name = "dendrite";

    src = sources.dendrite;

    prePatch = ''
      sed -e 's%//db.Exec("PRAGMA journal_mode=WAL;")%db.Exec("PRAGMA journal_mode=WAL;")%g' -i roomserver/storage/sqlite3/storage.go
    '';

    vendorSha256 = "03qg1rx3ww2l4gbrms2y6chxv8qwzbjh7vmb3kqsrisvra2r1y89";
  };


  dex = self.buildGoModule {
    name = "dex";
    src = sources.dex;

    subPackages = [ "cmd/dex" ];

    vendorSha256 = "1gqp9wqd1v0mrdjq7pj6c8n22si308q16a3bq6r42qqiiyqmxwaq";
  };

  matrix-static = unstable.buildGoModule {
    name = "matrix-static";
    src = sources.matrix-static;
    nativeBuildInputs = [ unstable.quicktemplate ];

    preBuild = ''
      qtc
    '';

    subPackages = [ "cmd/..." ];

    vendorSha256 = "14s70q7zabdk4njkqmg04gac2kpf54afxrqhglxdc3pwy7l7jhy4";

    passthru.assets = sources.matrix-static + "/assets";
  };

  esp32Pkgs = import sources.nixpkgs-esp32 {
    inherit (self) system;
    overlays = let buildPackages = self; in
      [
        (self: super:
          let
            python3 = buildPackages.python3.override {
              self = python3;
              packageOverrides = s: super: {
                cryptography = super.cryptography.overridePythonAttrs (_: { doCheck = false; });
                pyparsing = super.pyparsing.overridePythonAttrs (old: rec {
                  version = "2.3.1";
                  src = s.fetchPypi {
                    pname = "pyparsing";
                    inherit version;
                    sha256 = "66c9268862641abcac4a96ba74506e594c884e3f57690a696d21ad8210ed667a";
                  };
                });
              };
            };
            py = (python3.withPackages (p: with p; [
              pyserial
              future
              cryptography
              setuptools
              pyelftools
              pyparsing
              click
              ecdsa
              kconfiglib
              reedsolo
              python-socketio
              bitstring
              construct
            ]));
          in
          {
            # ESP32 SDK
            esp-idf = self.runCommandNoCC "esp-idf"
              {
                src = self.fetchgit {
                  url = "https://github.com/espressif/esp-idf.git";
                  rev = "v4.2";
                  sha256 = "0h60xnxny0q4m3mqa1ghr2144j0cn6wb7mg3nyn31im3dwclf68h";
                  fetchSubmodules = true;
                };
                nativeBuildInputs =
                  [ py ];
                passthru.python = py;
              } ''
              set -ex
              python --version
              cp -r --no-preserve=mode $src $out
              # nuke the requirements to make the toolchain happy
              echo > $out/requirements.txt
              echo $PATH
              chmod +x $out/tools/*.py
              patchShebangs --build $out/tools
              cd $out
              set +ex
            '';

            # ESP32 Framework
            smooth = self.runCommandNoCC "smooth"
              {
                src = self.fetchgit {
                  url = "https://github.com/PerMalmberg/Smooth.git";
                  fetchSubmodules = true;
                  rev = "b4bf80b4c5195e1c5d5c39f8285142e2af523d93";
                  sha256 = "0dy0vjwcyw7s1w44p0xgmbd24f58idmnmsx56wkp1iapx33gsvw3";
                };
              } ''
              cp -r --no-preserve=mode $src $out
              cd $out
              sed -e '1 p #include <mutex>' -i lib/smooth/include/smooth/core/io/i2c/I2CMasterDevice.h
            '';
          })
      ];
  };

  watering = self.esp32Pkgs.pkgsCross.esp32.callPackage ./watering { };
}
