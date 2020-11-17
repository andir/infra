{
  # FIXME: I shouldn't have the loopback addresses on the wireguard links.
  #        If a single wireguard link goes down that loopback address is not
  #        reachable anymore while we would be able to find a path thtorugh the
  #        network to the address via another peer.
  # FIXME: Currently I have to specify the loopback addresses both here and on
  #        the individual server config. This file should be sufficient to construct
  #        the fullmesh.
  h4ck.wireguard.hosts = {
    mon = {
      addresses = [
        "fe80::2/64"
        "172.20.25.1/32"
        "fd21:a07e:735e:ffff::2/128"
      ];

      publicKey = "SSywq3RQZqQDOBDNBIliVxTXVaOGwCPBpGkzZtvuSU8=";
    };
    bertha = {
      addresses = [
        "fe80::1/64"
        "172.20.25.4/32"
        "fd21:a07e:735e:ffff::1/128"
      ];
      publicKey = "6A8qvwQnxOqo8EPntT7VmoR6PVUI7fHhE6zs8P7rVGk=";
      hostName = null;
    };
    iota = {
      addresses = [
        "fe80::3/64"
        "172.20.25.2/32"
        "fd21:a07e:735e:ffff::3/128"
      ];
      publicKey = "s6OL5S5GvUykOs1XVAWL2i6Mflk6niZ4BZhrHmdB5Gw=";
      hostName = "iota.h4ck.space.";
    };
    "kack.it" = {
      addresses = [
        "fe80::4/64"
        "172.20.25.3/32"
        "fd21:a07e:735e:ffff::4/128"
      ];
      publicKey = "AOZtvBNivncFXxExEzNR91hIW1RkzpgHOkEHDy6Pn3A=";
      hostName = "kack.it";
    };
  };
}
