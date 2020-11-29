{ sources, system, config }:
let
  unstable = import sources.nixpkgs-unstable { inherit system config; };
in
self: super: {
  inherit sources unstable;

  ate = self.callPackage sources.ate { };

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

  morph = (unstable.callPackage (sources.morph + "/nix-packaging") { }).overrideAttrs (
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
        rev = "f7b0ba5592b8fee0955393eaf5377889f2873a4d";
        sha256 = "1xldd4q7fv7da40prb50mnnz5sl2dpv8d0hkzhc8bzz4m3wq5l40";
      };
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

  firefox-unwrapped = super.firefox-unwrapped.overrideAttrs ({ patches ? [ ], ... }: {
    patches = patches ++ [
      (super.fetchpatch {
        # source: https://bugzilla.redhat.com/show_bug.cgi?id=1897675
        name = "rh-bgz-1897675.patch";
        url = "https://github.com/mozilla/gecko-dev/commit/71597faac0fde4f608a60dd610d0cefac4972cc3.patch";
        sha256 = "1f61nsgbv2c2ylgjs7wdahxrrlgc19gjy5nzs870zr1g832ybwin";
      })
    ];
  });

  linuxPackages = super.linuxPackagesFor (super.linux_5_4.override {
    extraConfig = ''
      IPV6 y
    '';
  });
}
