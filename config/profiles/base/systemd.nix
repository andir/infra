{ pkgs, ... }:
{
  # Apply a patched systemd version
  # see https://github.com/systemd/systemd/issues/17232
  systemd.package = pkgs.systemd-boot;
}
