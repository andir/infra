{ pkgs ? import ../nix/default.nix { } }:
let
  cloud-init = (
    builtins.toJSON {
      write_files = [
        {
          path = "/run/bootstrap.nix";
          content = builtins.readFile ./boot.nix;
        }
        {
          path = "/run/root.keys";
          content = builtins.readFile ../config/profiles/base/andi.pub;
        }
        {
          path = "/boot-to-nixos.sh";
          permissions = "0755";
          content = ''
            #!/usr/bin/env bash
            set -ex
            echo start of boot-to-nixos > /dev/kmsg
            # install curl
            apt-get update
            apt-get install -y curl git
            echo dependencies installed > /dev/kmsg
    
            # add user to drive the installer with
            echo 'silly    ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
            useradd -m silly
    
            echo user added > /dev/kmsg
            # bootstrap nix
            curl -o /run/nix.tar.xz https://nixos.org/releases/nix/nix-2.3.2/nix-2.3.2-x86_64-linux.tar.xz
            echo Nix downloaed > /dev/kmsg
            # verify that we didn't download trash
            echo bd4cb069d16417ba4aadc5bb005fdb263823990352f9d37c5b763a0bd145394f  /run/nix.tar.xz | sha256sum -c -
            echo Nix verified > /dev/kmsg
            # unpack and run install
            cd /run && tar -xf ./nix.tar.xz && mv ./nix-* nix
            echo Installing Nix > /dev/kmsg
            sudo -i -u silly -- bash /run/nix/install
    
            # build the installer environment
            echo building bootstrap files > /dev/kmsg
            sudo -i -u silly -- nix-build /run/bootstrap.nix --out-link /home/silly/bootstrap
            # exec into the installer
            echo kexecing > /dev/kmsg
            /home/silly/bootstrap
          '';
        }
        {
          path = "/etc/systemd/system/boot-to-nixos.service";
          content = ''
            [Install]
            WantedBy=multi-user.target

            [Service]
            ExecStart=/boot-to-nixos.sh
          '';
        }
      ];
      runcmd = [
        "systemctl daemon-reload"
        "systemctl start boot-to-nixos.service"
      ];
    }
  );
in
pkgs.writeText "cloud-init" ''
  #cloud-config
  ${cloud-init}
''
