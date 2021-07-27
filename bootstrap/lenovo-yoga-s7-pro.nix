{ pkgs ? import ../nix/default.nix { } }:
let

in
{
  isoGnome = (pkgs.nixos {
    imports = [
      ({ config, modulesPath, pkgs, ... }: {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-graphical-gnome.nix") ];
        boot.kernelModules = [
          "rtw89"
        ];

        nixpkgs.overlays = [
          (self: super: {
            linux_latest = super.linux_latest.override {
              extraConfig = ''
                THINKPAD_ACPI_DEBUG y
              '';
            };
          })
        ];

        boot.extraModulePackages = [ config.boot.kernelPackages.rtw89 ];


        boot.kernelPackages = (pkgs.linuxPackagesFor pkgs.linux_latest).extend (self: super: {
          rtw89 = self.rtw88.overrideAttrs (_: {
            pname = "rtw89";
            version = "unstable";
            src = pkgs.fetchFromGitHub {
              owner = "lwfinger";
              repo = "rtw89";
              rev = "fe961ee01e9210d21c4ded7ccf009a8823a1364e";
              sha256 = "0lxfdjyrlyz8r1y8sqk7lg463gi6bhbk4fh8f69kwwg4cdbhas6m";
            };
          });
        });
      })
    ];
  }).config.system.build.isoImage;
}
