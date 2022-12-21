{ pkgs, ... }:
{
  systemd.sockets.atftpd = {
    listenDatagrams = [ "192.168.1.88:69" ];
    wantedBy = [ "sockets.target" ];
  };

  systemd.services.atftpd = {
    requires = [ "atftpd.socket" ];
    serviceConfig = {
      StateDirectory = "atftpd";
      DynamicUser = true;
      StandardInput = "socket";
      ExecStart = "${pkgs.atftp}/bin/atftpd -v 6 -m 2 --port 69 --tftpd-timeout 300 --retry-timeout 5 --mcast-port 1758 --mcast-addr 239.239.239.0-255 --mcast-ttl 1 /var/lib/atftpd";
      WorkingDirectory = "/var/lib/atftpd";
    };
  };
}
