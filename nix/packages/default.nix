{ sources }:
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
}
