{ pkgs ? import ../nix/default.nix }:
let
  cloud-init = (builtins.toJSON {
    write_files = [
      {
        path = "/run/bootstrap.nix";
        content = builtins.readFile ./boot.nix;
      }
      {
        path = "/run/root.keys";
        content = builtins.readFile ../config/profiles/base/andi.pub;
      }
    ];
    bootcmd = [
      # install curl
      "apt-get update"
      "apt-get install -y curl"

      # add user to drive the installer with
      "echo 'silly    ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
      "useradd silly"
      # bootstrap nix
      "curl -o /run/nix.tar.xz https://nixos.org/releases/nix/nix-2.3.2/nix-2.3.2-x86_64-linux.tar.xz"
      # verify that we didn't download trash
      "echo bd4cb069d16417ba4aadc5bb005fdb263823990352f9d37c5b763a0bd145394f  /run/nix.tar.xz | sha256sum -c -"
      # unpack and run install
      "cd /run && tar -xf ./nix.tar.xz && mv ./nix-* nix"
      "systemd-run --property=After=local-fs.target --property=User=silly /run/nix/install --daemon"

      # build the installer environment
      "systemd-run --property=After=local-fs.target nix-build /run/bootstrap.nix --out-link /run/bootstrap"
      # exec into the installer
      "systemd-run --property=After=multi-user.target /run/bootstrap"
    ];
  });
in pkgs.writeText "cloud-init" ''
#cloud-config
${cloud-init}
''
