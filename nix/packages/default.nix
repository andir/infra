{ sources, system, config }:
let
  unstable = import sources.nixpkgs-unstable {
    inherit system config; overlays =
    (import ../overlays.nix { inherit system config; });
  };

in
self: super: {
  inherit sources unstable;
  nativePkgs = import self.path {
    system = builtins.currentSystem; # purposely the system that drives the eval/build!
    overlays = (import ../overlays.nix { inherit config; system = builtins.currentSystem; });
  };

  ate = self.callPackage sources.ate { };

  # use unstable because of the cargoLock based import
  npins = unstable.callPackage sources.npins { };

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

  bird = (if super.bird.version == "1.6.8" then super.bird2 else super.bird).overrideAttrs (
    { patches ? [ ], configureFlags ? [ ], nativeBuildInputs ? [ ], ... }: {

      #configureFlags = configureFlags ++ [ "--enable-debug" ];
      nativeBuildInputs = nativeBuildInputs ++ [ self.autoreconfHook ];
      src = sources.bird;
      # we have to remove a patch that nixpkgs fetches but that already is in our tree
      patches = builtins.filter (patch: builtins.typeOf patch == "path") (patches ++ [
      ]);
    }
  );

  bird2 = self.bird;

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

  my-libtensorflow-bin = unstable.callPackage ./libtensorflow-bin.nix { };
  photoprism = unstable.callPackage ./photoprism {
    src = sources.photoprism;
  };

  fping_exporter = self.callPackage ./fping-exporter.nix { };

  rockpi4 = self.callPackage ./rockpi4 { };

  lego = super.lego.overrideAttrs (_: {
    #patches = [
    #  ./lego-retry.diff
    #];
  });

  python3 = super.python3.override {
    packageOverrides = _: psuper: {
      psautohint = psuper.psautohint.overridePythonAttrs (_: { doCheck = false; });
    };
  };

  dendrite = unstable.buildGo119Module {
    name = "dendrite";

    src = sources.dendrite;

    prePatch = ''
      sed -e 's%//db.Exec("PRAGMA journal_mode=WAL;")%db.Exec("PRAGMA journal_mode=WAL;")%g' -i roomserver/storage/sqlite3/storage.go
    '';

    vendorSha256 = "03qg1rx3ww2l4gbrms2y6chxv8qwzbjh7vmb3kqsrisvra2r1y89";
  };


  dex = self.buildGo118Module {
    name = "dex";
    src = sources.dex;

    subPackages = [ "cmd/dex" ];
    vendorSha256 = "sha256-wkuh/XpHvTnKsVA1Z/YOQFFi+D+vSJ06RO7uASgoXZY=";
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
              patchShebangs --build $out/components/esptool_py/esptool
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

  my-zigbee2mqtt = self.npmlock2nix.v1.build rec {
    src = sources.zigbee2mqtt;
    nodejs = self.nodejs-14_x;
    node_modules_attrs = {
      packageLockJson = src + "/package-lock.json";
      nativeBuildInputs = [ self.python3 self.nukeReferences ];
      postBuild = ''
        find . -type f -iname "package.json" -exec nuke-refs {} \;
      '';
    };
    buildCommands = [
      "npm run build"
    ];
    installPhase = ''
      mkdir -p $out/lib/node_modules
      cp -r . $out/lib/node_modules/zigbee2mqtt
      mkdir -p $out/bin
      find $out/lib/node_modules -type f -iname "package.json" -delete
      cat - <<EOF > $out/bin/zigbee2mqtt
      #!/usr/bin/env sh
      export NODE_PATH="${placeholder "out"}/lib/node_modules/zigbee2mqtt:${placeholder "out"}/lib/node_modules/zigbee2mqtt/node_modules"
      set -ex
      cd ${placeholder "out"}/lib/node_modules/zigbee2mqtt
      exec ${nodejs}/bin/node ./index.js
      EOF
      chmod +x $out/bin/zigbee2mqtt

      # zigbee2mqtt now checks the configured engine version during runtime
      cp package.json $out/lib/node_modules/zigbee2mqtt/
    '';
  };

  # postgresql with JIT enabled to speedup CPU intensive operations
  postgresql_12_jit = self.postgresql_12.overrideAttrs ({ nativeBuildInputs, configureFlags, ... }: {
    nativeBuildInputs = nativeBuildInputs ++ [ self.llvm self.clang ];
    configureFlags = configureFlags ++ [ "--with-llvm" ];
  });


  nixos-dev-website = super.runCommandNoCC "nixos.dev-website"
    {
      nativeBuildInputs = [ self.pandoc ];
      src = ../../config/servers/nixos-dev/website;
    } ''
    set -ex
    mkdir $out
    pandoc -f markdown -t html -s --data-dir $out -o $out/index.html $src/index.md
    set +x
  '';

  spacesbot = super.callPackage ./spacesbot { };

  fastPython3 = self.python3.override {
    enableOptimizations = true;
    reproducibleBuild = false;
    self = self.fastPython3;
    pythonAttr = "fastPython3";
    packageOverrides = (pyself: pysuper: {
      # https://lore.kernel.org/all/20221226132753.44175-1-kuniyu@amazon.com/
      ephemeral-port-reserve = pysuper.ephemeral-port-reserve.overrideAttrs (_: {
        doCheck = false;
        checkInputs = [ ];
        pytestCheckPhase = "true";
      });
    });
  };

  matrix-synapse = (super.matrix-synapse.override {
    python3 = self.fastPython3;
  }).overrideAttrs ({ patches ? [ ], ... }: {
    patches = patches ++ [ ../../matrix-logging.patch ];
  });

  compact-matrix-states = self.callPackage ./compact-matrix-states.nix { };

  mumble-web = self.npmlock2nix.v1.build {
    src = sources.mumble-web;
    buildCommands = [ "npm run build" ];
    installPhase = "cp dist $out";
  };

  dashjs_src = self.fetchzip {
    url = "https://github.com/Dash-Industry-Forum/dash.js/archive/refs/tags/v4.0.1.zip";
    sha256 = "1q1jbrh41h9yviprla88872dfm2w0wmp8iv2gn343biw92wn6zlg";
  };

  dashjs = self.runCommand "dash.js"
    {
      inherit (self) dashjs_src;
    } ''
    cp $dashjs_src/dist/dash.all.min.js $out
  '';

  streetmerchant = self.callPackage ./streetmerchant.nix { };

  matrix-org-olm = self.emscriptenStdenv {
    name = "matrix-org-olm";
    nativeBuildInputs = [ self.emscripten self.python3 self.closurecompiler ];
    src = sources.matrix-org-olm;
    postUnpack = ''
      patchShebangs $PWD
    '';

    EM_CLOSURE_COMPILER = "closure-compiler";

    makeFlags = [ "js" ];

    installPhase = ''
      cp -rv javascript $out
    '';
  };

  cinny = self.npmlock2nix.v2.build {
    src = sources.cinny;

    installPhase = [ "cp -r dist $out" ];
    node_modules_attrs = {
      buildInputs = [ self.vips ];
      nativeBuildInputs = [ self.pkgconfig self.python3 ];
    };

    # preBuild = ''
    #   sed -e "/'process.env': JSON.stringify(process.env),/d" -i webpack.common.js
    # '';

    passthru.withConfig = config: self.runCommand "cinny-with-config"
      {
        cinny = self.cinny;
        config = builtins.toJSON config;
        passAsFile = [ "config" ];
      } ''
      cp -rv $cinny $out
      rm $out/config.json || :
      chmod +rw -R $out
      cp $configPath $out/config.json
    '';
  };

  element-web = super.element-web.overrideAttrs (old:
    let
      version = "1.9.7";
    in
    if self.lib.versionOlder old.version "1.9.6" then {
      version = version;
      src = super.fetchurl {
        url = "https://github.com/vector-im/element-web/releases/download/v${version}/element-v${version}.tar.gz";
        sha256 = "sha256-Q/PAHunpIq/+wnj8DMW5yf87k65pCHYnQXrzhe23obs=";
      };
    } else { });

  lovelaceModules = self.callPackage ./lovelaceModules.nix { inherit sources; };

  mopidy-radionet = self.python3Packages.buildPythonApplication {
    pname = "mopidy-radionet";
    version = sources.mopidy-radionet.release_name;
    src = sources.mopidy-radionet;
    propagatedBuildInputs = [ self.mopidy self.python3Packages.uritools ];
    doCheck = false; # requires network access :(
  };


  # when doing cross/binfmt builds just use native fonts as I don't
  # have time to watch it compress PNGs anymore..
  noto-fonts-emoji = if self.system == builtins.currentSystem then super.noto-fonts-emoji else self.nativePkgs.noto-fonts-emoji;

  dotagsi = self.callPackage sources.dotagsi { };

  lwnfeed = self.buildGoModule {
    name = "lwnfeed";
    src = sources.lwnfeed;
    vendorSha256 = "091c8lgldihia0vlhigjx7vc9sx640jlz7sg3wx31fpcyml0zy6v";
    ldflags = [ "-s" "-w" "-X main.BuildTime=2022-10-13T21:11:00Z" ];
  };

  shairport-sync = super.shairport-sync.overrideAttrs (_: {
    src = super.fetchFromGitHub {
      owner = "mikebrady";
      repo = "shairport-sync";
      rev = "4.1";
      sha256 = "sha256-iEiKOOFZE8rxyJpCJI1mx4M03iHRlujNvQypuhG4cu8=";
    };
  });

  gotosocial = unstable.buildGoModule {
    pname = "gotosocial";
    version = sources.gotosocial.version;
    src = sources.gotosocial;
    #goPackagePath = "github.com/superseriousbusiness/gotosocial";
    vendorSha256 = null;
    buildFlags = [ "-trimpath" "-buildmode=pie" ];
    ldFlags = [ "-static" "-x" "-w" "-extldflags" "-static" "-X main.Version=${sources.gotosocial.version}" ];
    CGO_ENABLE = "0";
  };
}
