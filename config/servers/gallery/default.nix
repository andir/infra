{
  imports = [
    ../../profiles/hetzner-vm.nix
    ./piwigo.nix
  ];

  deployment = {
    targetHost = "159.69.192.67";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "159.69.192.67/32"
      "2a01:4f8:c2c:2ae2::/128"
    ];
  };
  fileSystems."/".fsType = "btrfs";
}
