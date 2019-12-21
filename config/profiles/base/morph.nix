{
  # user for deployment and morph usage
  users.users.morph = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [
      ./andi.pub
    ];
  };

  nix.trustedUsers = [ "morph" ];
}
