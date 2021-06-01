{
  h4ck.monitoring.targets."zeta-node-exporter" = {
    targetHost = "zeta.rammhold.de";
    port = 9100;
  };

  h4ck.monitoring.targets."node-mail.radgo.at." = {
    targetHost = "mail.radgo.at";
    port = 9100;
  };

  h4ck.monitoring.targets."matrix.hackint.org" = {
    targetHost = "matrix.hackint.org";
    port = 9100;
  };

  h4ck.monitoring.targets."matrix.hackint.org-synapse" = {
    targetHost = "matrix.hackint.org";
    port = 443;
    job_config = {
      scheme = "https";
      metrics_path = "/synapse-metrics";
    };
  };

  h4ck.monitoring.targets."matrix.hackint.org-appservice" = {
    targetHost = "matrix.hackint.org";
    port = 443;
    job_config = {
      scheme = "https";
      metrics_path = "/appservice-metrics";
    };
  };
}
