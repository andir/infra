{ sources }:
let
  unstable = import sources.nixpkgs-unstable {};
in
self: super: {
  knot_exporter = self.callPackage ./knot_exporter.nix {
    src = sources.knot_exporter;
  };
  prometheus-xmpp-alerts = self.callPackage ./prometheus-xmpp-alerts.nix {};
  grafanaPlugins = {
    statusmap = super.fetchFromGitHub {
      owner = "flant";
      repo = "grafana-statusmap";
      rev = "v0.2.0";
      sha256 = "1franflr7xci8zdcd5qmqxxalnimjpz2yyhpa51la5d16mnmch9r";
    };
  };

  morph = (unstable.callPackage (sources.morph + "/nix-packaging") {}).overrideAttrs (
    _: {
      patches = [ ./morph-evalConfig-machinename.patch ];
    }
  );

  bird2 = super.bird2.overrideAttrs (
    { patches ? [], ... }: {
      patches = patches ++ [
        (
          super.fetchpatch {
            url = "https://github.com/openwrt-routing/packages/raw/37f8c509e03de355a3d0f9b6d62837c43750f98b/bird2/patches/0001-babel-Set-onlink-flag-for-IPv4-routes-with-unreachab.patch";
            sha256 = "08x5awza514r6745l5cg0mwlh7pcbxsws9y8hmjmk831wdqgjlln";
          }
        )
      ];
    }
  );

  dn42-regparse = self.callPackage sources.dn42-regparse {};
  dn42-roa = let
    roa = self.runCommand "dn42-roa" {
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
}
