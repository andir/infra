{
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
        "172.20.24.1/32"
        "fd21:a07e:735e:ffff::1/128"
      ];
      publicKey = "6A8qvwQnxOqo8EPntT7VmoR6PVUI7fHhE6zs8P7rVGk=";
      hostName = null;
    };
    gitlab-runner = {
      addresses = [
        "fe80::3/64"
        "172.20.25.2/32"
        "fd21:a07e:735e:ffff::3/128"
      ];
      publicKey = "s6OL5S5GvUykOs1XVAWL2i6Mflk6niZ4BZhrHmdB5Gw=";
      hostName = "95.216.155.219";
    };
  };
}
