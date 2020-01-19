let
  pkgs = import <nixpkgs> {};
  src = builtins.fetchTarball https://github.com/nix-community/nixos-generators/archive/942232e3000e80b4b4ad34cb3c07923415c27493.tar.gz;
  generator = import (src + "/nixos-generate.nix");

#  diskoSrc = builtins.fetchTarball https://github.com/nix-community/disko/archive/1af856886eca80ce39b61fd97816e4b3be07b236.tar.gz;

#  disko = import diskoSrc;

#  partitionDisk = disko.create cfg;

in generator {
  format-config = src + "/formats/kexec-bundle.nix";
  configuration = ({ config, ... }: {
    users.users.root.openssh.authorizedKeys.keyFiles = [ /run/root.keys ];
    services.openssh.enable = true;
  });
}
