{ python38, src, writeScriptBin, runCommand, stdenv }:
let
  pyEnv = python38.withPackages (p: [ p.prometheus_client ]);
  script = writeScriptBin "knot_exporter" ''
    #!${stdenv.shell}
    exec ${pyEnv}/bin/python ${src}/knot_exporter "$@"
  '';

  pkg = runCommand "knot-exporter-tested" {
    buildInputs = [ script ];
  } ''
    set -e
    knot_exporter --help
    ln -s ${script}/bin/knot_exporter $out
  '';
in
pkg
