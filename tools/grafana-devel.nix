{ stdenv, lib, grafana, writeScriptBin, symlinkJoin, writeTextFile, grafanaPlugins ? { }, grafana-dashboards }:
let
  provision = symlinkJoin {
    name = "provision-files";
    paths = [
      (
        writeTextFile {
          name = "default.json";
          destination = "/dashboards/default.yaml";
          text = builtins.toJSON {
            apiVersion = 1;
            providers = [
              {
                name = "Static dashboards";
                folder = "";
                options.path = grafana-dashboards;
                orgId = 1;
                type = "file";
                updateIntervalSeconds = 60;
              }
            ];
          };
        }
      )
      (
        writeTextFile {
          name = "default.json";
          destination = "/datasources/default.yaml";
          text = builtins.toJSON {
            apiVersion = 1;
            datasources = [
              {
                access = "proxy";
                basicAuth = null;
                basicAuthPassword = null;
                basicAuthUser = null;
                database = null;
                editable = false;
                isDefault = true;
                jsonData = null;
                name = "prometheus";
                orgId = 1;
                password = null;
                secureJsonData = null;
                type = "prometheus";
                url = "http://mon.h4ck.space:9090";
                user = null;
                version = 1;
                withCredentials = false;
              }
            ];
          };
        }
      )
    ];
  };
in
writeScriptBin "grafana-devel" ''
    #! ${stdenv.shell}

    set -ex

    DIR=$(mktemp -d)
    cd $DIR
    mkdir -p {data,log,plugins}

    trap "{ rm -f "$DIR" }" EXIT

    export GF_PATHS_PROVISIONING=${provision}
    export GF_SERVER_HTTP_ADDR=127.0.0.1
    export GF_SERVER_STATIC_ROOT_PATH=${grafana}/share/grafana/public
    export GF_AUTH_ANONYMOUS_ENABLED=true
    export GF_AUTH_ANONYMOUS_ORG_NAME="Main Org."
    export GF_AUTH_ANONYMOUS_ORG_ROLE="Admin"
    export GF_ANALYTICS_REPORTING_ENABLED=false
    export GF_SECURITY_ADMIN_USER="admin"
    export GF_SECURITY_ADMIN_PASSWORD="admin"
    export GF_SECURITY_SECRET_KEY=asdfasdfasdfasdfasdf
    export GF_PATHS_DATA="$DIR/data"
    export GF_PATHS_LOGS="$DIR/log"
    export GF_PATHS_PLUGINS="$DIR/plugins"
    export GF_DATABASE_TYPE="sqlite3"
    export GF_DATABASE_PATH="$DIR/data/grafana.db"
    export GF_DATABASE_NAME="grafana"

    ln -sf ${grafana}/share/grafana/conf conf
    ln -sf ${grafana}/share/grafana/tools tools
    ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList
  (
      pluginName: plugin:
        "ln -s ${toString plugin} plugins/${pluginName}"
    )
  grafanaPlugins
  )}
    exec ${grafana}/bin/grafana-server "$@"
''
