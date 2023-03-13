{ matrix-synapse-tools, writeShellScriptBin, postgresql, database_name ? "matrix-synapse", username ? "matrix-synapse" }:
writeShellScriptBin "compact-matrix-states" ''
  exec ${matrix-synapse-tools.rust-synapse-compress-state}/bin/synapse_auto_compressor -p "host=/run/postgresql/ user=${username} dbname=${database_name}" -c 10 -n 100
''
