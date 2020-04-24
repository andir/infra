let
  # import secrets if they exist (e.g. on deployment hosts)
  secrets =
    let
      path = ../../../secrets/alerts.nix;
      default = {
        config = {};
        rules = [];
      };
    in
      if builtins.trace path builtins.pathExists path then import path else default;
in
{

  imports = [ secrets.config ];

  services.prometheus.rules = [
    (
      builtins.toJSON {
        groups = [
          {
            name = "rules";
            rules = secrets.rules ++ [
              {
                alert = "ICMP probe unsucessfull";
                expr = ''
                  probe_success{job=~"^blackbox_icmp_.+"} == 0
                '';
                for = "3m";
                annotations = {
                  description = "ICMP replies to {{ $labels.instance }} gone missing.";
                  summary = "ICMP replies missing {{ $labels.instance }}";
                };
              }
              {
                alert = "ExporterDown";
                expr = "up == 0";
                for = "5m";
                annotations = {
                  description = "An exporter is down for more than 5 minutes";
                  summary = "Exporter {{ $labels.instance }} is down";
                };
              }
              {
                alert = "InstanceLowDiskAbs";
                expr = ''node_filesystem_avail_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!="/boot"} / 1024 / 1024 < 1024'';
                for = "1m";
                labels = {
                  severity = "page";
                };
                annotations = {
                  description = "Less than 1GB of free disk space left on the root filesystem";
                  summary = "Instance {{ $labels.instance }}: {{ $value }}MB free disk space on {{$labels.device }} @ {{$labels.mountpoint}}";
                  value = "{{ $value }}";
                };
              }
              {
                alert = "InstanceLowDiskPerc";
                expr = "100 * (node_filesystem_free_bytes / node_filesystem_size_bytes) < 10";
                for = "1m";
                labels = {
                  severity = ";page";
                };
                annotations = {
                  description = "Less than 10% of free disk space left on a device";
                  summary = "Instance {{ $labels.instance }}: {{ $value }}% free disk space on {{ $labels.device}}";
                  value = "{{ $value }}";
                };
              }
              {
                alert = "InstanceLowDiskPrediction12Hours";
                expr = ''predict_linear(node_filesystem_free_bytes{fstype!~"(tmpfs|ramfs)"}[3h],12 * 3600) < 0'';
                for = "2h";
                labels.severity = "page";
                annotations = {
                  description = ''Disk {{ $labels.mountpoint }} ({{ $labels.device }}) will be full in less than 12 hours'';
                  summary = ''Instance {{ $labels.instance }}: Disk {{ $labels.mountpoint }} ({{ $labels.device}}) will be full in less than 12 hours'';
                };
              }

              {
                alert = "InstanceLowMem";
                expr = "node_memory_MemAvailable_bytes / 1024 / 1024 < node_memory_MemTotal_bytes / 1024 / 1024 / 10";
                for = "3m";
                labels.severity = "page";
                annotations = {
                  description = "Less than 10% of free memory";
                  summary = "Instance {{ $labels.instance }}: {{ $value }}MB of free memory";
                  value = "{{ $value }}";
                };
              }

              {
                alert = "ServiceFailed";
                expr = ''node_systemd_unit_state{state="failed"} > 0'';
                for = "2m";
                labels.severity = "page";
                annotations = {
                  description = "A systemd unit went into failed state";
                  summary = "Instance {{ $labels.instance }}: Service {{ $labels.name }} failed";
                  value = "{{ $labels.name }}";
                };
              }
              {
                alert = "ServiceFlapping";
                expr = ''changes(node_systemd_unit_state{state="failed"}[5m])
                > 5 or (changes(node_systemd_unit_state{state="failed"}[1h]) > 15
                unless changes(node_systemd_unit_state{state="failed"}[30m]) < 7)
              '';
                labels.severity = "page";
                annotations = {
                  description = "A systemd service changed its state more than 5x/5min or 15x/1h";
                  summary = "Instance {{ $labels.instance }}: Service {{ $labels.name }} is flapping";
                  value = "{{ $labels.name }}";
                };
              }
            ];
          }
        ];
      }
    )
  ];
}
