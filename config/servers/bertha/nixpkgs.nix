{
  # fixup the broken mdmonitor unit by masking it
  systemd.units."mdmonitor.service".enable = false;
}
