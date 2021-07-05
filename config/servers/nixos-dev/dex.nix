{ config, pkgs, utils, ... }:
let
  secret = path: { _secret = path; };
  oidc_config = {
    oidc_providers = [
      {
        idp_id = "dex";
        idp_name = "NixOS GitHub Org Membership";
        issuer = "https://auth.nixos.dev/dex";
        client_id = "synapse";
        client_secret = secret "/run/dex-synapse/client_secret";
        scopes = [ "openid" "profile" ];
        user_mapping_provider = {
          config = {
            subject_claim = "sub";
            localpart_template = "{{ user.preferred_username }}";
            display_name_template = "{{ user.name }}";
          };
        };
      }
    ];
  };

in
{

  # Roll random client_secrets for the dex <> matrix-synapse integration.
  # The key can be different on each boot as there are not external systems involved in this at all.
  systemd.tmpfiles.rules = [
    "d /run/dex-synapse 0700 root root -"
  ];
  systemd.services.dex-roll-random-client-secrets = {
    wantedBy = [ "multi-user.target" ];
    before = [ "dex.service" "matrix-synapse.service" ];
    path = [ pkgs.utillinux ];

    script = ''
      set -e
      cd /run/dex-synapse
      if ! test -f client_secret; then
        printf "%s-%s" $(uuidgen) $(uuidgen) > client_secret
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
    };
  };


  deployment.secrets = {
    "dex-github-client-id" = {
      source = toString ../../../secrets/dex-github-client-id;
      destination = "/run/keys/dex-github-client-id";
      action = [ "sudo" "systemctl" "restart" "dex" ];
    };
    "dex-github-client-secret" = {
      source = toString ../../../secrets/dex-github-client-secret;
      destination = "/run/keys/dex-github-client-secret";
      action = [ "sudo" "systemctl" "restart" "dex" ];
    };
  };
  h4ck.dex = {
    enable = true;
    issuer = "https://auth.nixos.dev/dex";
    connectorsConfig = [
      {
        type = "github";
        id = "github";
        name = "GitHub";
        config =
          {
            clientId = secret "/run/keys/dex-github-client-id";
            clientSecret = secret "/run/keys/dex-github-client-secret";
            redirectURI = "https://auth.nixos.dev/dex/callback";
            orgs = [
              {
                name = "NixOS";
              }
              #{
              #  name = "some-test-org123";
              #}
            ];
          };
      }
    ];

    staticClientsConfig = [
      {
        id = "synapse";
        name = "synapse";
        secret = secret "/run/dex-synapse/client_secret";
        redirectURIs = [
          "https://matrix.nixos.dev/_synapse/client/oidc/callback"
        ];
      }
    ];
  };

  services.nginx.virtualHosts."auth.nixos.dev" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://${config.h4ck.dex.listenAddress}:${toString config.h4ck.dex.listenPort}";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;'';
    };
  };

  services.matrix-synapse.extraConfigFiles = [
    "/run/matrix-synapse/oidc.yml"
  ];
  systemd.services.matrix-synapse.serviceConfig = {
    ExecStartPre = [
      "+${(pkgs.writeShellScript "oidc-config-secrets.sh" ''
      umask 066
      ${utils.genJqSecretsReplacementSnippet oidc_config "/run/matrix-synapse/oidc.yml"}
      chmod 600 /run/matrix-synapse/oidc.yml
      chown matrix-synapse: /run/matrix-synapse/oidc.yml
    '')}"
    ];
    RuntimeDirectory = "matrix-synapse";
  };
}
