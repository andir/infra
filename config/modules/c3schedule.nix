{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.c3schedule;
  configTemplate = pkgs.writeText "sopel.conf" (
    lib.generators.toINI { } (
      cfg.config // {
        core = (cfg.config.core or { }) // {
          extra = toString (
            pkgs.runCommand "extra-modules" { } ''
              mkdir $out
              ln -s ${pkgs.c3schedule.sopelModule} $out/c3schedule
            ''
          );
        };
      }
    )
  );
in
{
  options.c3schedule = {
    enable = mkEnableOption "Enable c3schedule";
    config = mkOption {
      type = types.attrs;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    users.users.c3schedule = {
      home = "/var/lib/c3schedule";
      createHome = true;
      isNormalUser = true;
    };

    systemd.services.c3schedule = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        User = "c3schedule";
        EnvironmentFile = "/var/lib/secrets/c3schedule.env";
      };
      preStart = ''
        sed -e "s/@AUTH_PASSWORD@/$AUTH_PASSWORD/" < "${configTemplate}" > /var/lib/c3schedule/sopel.conf
      '';
      script = ''
        cd /var/lib/c3schedule
        ${pkgs.c3schedule.bin}/bin/c3schedule -c sopel.conf
      '';
    };
  };
}
