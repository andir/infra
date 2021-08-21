{ matrix-synapse-tools, writeShellScriptBin, postgresql, database_name ? "matrix-synapse", username ? "matrix-synapse" }:
writeShellScriptBin "compact-matrix-states" ''
  export PATH="${matrix-synapse-tools.rust-synapse-compress-state}/bin/:${postgresql}/bin:$PATH"
  set -ex

  TMP=$(mktemp -d)

  cd $TMP
  echo "SELECT room_id, count(*) FROM state_groups_state GROUP BY room_id" | psql --csv -t -F, ${database_name} | cut -f1 -d, | grep -v '^\s*$' > rooms.txt

  cat rooms.txt

  while read -r room_id; do
    echo "Compacting $room_id"
    synapse-compress-state -t -o state-compressor.sql \
      -p "host=/run/postgresql/ user=${username} dbname=${database_name}" \
      -r "$room_id"
    psql ${database_name} < state-compressor.sql
    ls -la state-compressor.sql
  done < rooms.txt

  rm $TMP/state-compressor.sql || :
  rm $TMP/rooms.txt
  rmdir $TMP
''
