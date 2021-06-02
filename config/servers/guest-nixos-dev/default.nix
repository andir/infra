{
  imports = [
    ../../profiles/hetzner-vm.nix
    ./matrix.nix
    ./dex.nix
    ./matrix-static.nix
  ];

  deployment = {
    targetHost = "guest.nixos.dev";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "65.21.56.233/32"
      "2a01:4f9:c010:4672::/128"
    ];
  };

  networking = {
    hostName = "guest";
    domain = "nixos.dev";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
    };
  };

  mods.hetzner.vm.persistentDisks."/persist".id = 11315455;
}
