{ sources }:
self: super: {
  knot_exporter = self.callPackage ./knot_exporter.nix {
    src = sources.knot_exporter;
  };
}
