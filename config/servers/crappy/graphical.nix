{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ate
    firefox
    (
      ((pkgs.kodi.withPackages (p: with p; [
        youtube
        netflix
        pvr-iptvsimple
        a4ksubtitles
        (p.buildKodiAddon {
          pname = "plugin.video.media-ccc-de";
          version = "git+" + pkgs.sources."plugin.video.media-ccc-de".revision;
          namespace = "plugin.video.media-ccc-de";
          src = sources."plugin.video.media-ccc-de";
          propagatedBuildInputs = with p; [
            requests
            routing
          ];
        })
      ])).override {
        kodi = (pkgs.kodi.override { waylandSupport = true; }).overrideAttrs ({ patches ? [ ], ... }: {
          patches = patches ++ [
            #(pkgs.fetchpatch {
            #  url = "https://github.com/xbmc/xbmc/pull/20632/commits/3f02f813997d19d15917fb4eb3387c60a3696837.patch";
            #  sha256 = "0f8f3245f3jg5ghvfyjhbvjvv3xz8gnbmhzwwvvdd55m3yz19m94";
            #})
          ];
        });
      })
    )
  ];

  networking.firewall.extraStopCommands = ''
    iptables -D INPUT -p tcp --dport 8080 -s 172.20.23.0/24 -j ACCEPT || : # kodi
    iptables -D INPUT -p tcp --dport 8080 -s 10.250.11.0/24 -j ACCEPT || : # kodi
    ip6tables -D INPUT -p tcp --dport 8080 -s fd21:a07e:735e:ff00::/64 -j ACCEPT  || # kodi
  '';

  networking.firewall.extraCommands = ''
    iptables -I INPUT 1 -p tcp --dport 8080 -s 172.20.23.0/24 -j ACCEPT || : # kodi
    iptables -I INPUT 1 -p tcp --dport 8080 -s 10.250.11.0/24 -j ACCEPT || : # kodi
    ip6tables -I INPUT 1 -p tcp --dport 8080  -s fd21:a07e:735e:ff00::/64 -j ACCEPT  || # kodi
  '';


  programs.sway = {
    enable = true;
    extraPackages = pkgs.lib.mkForce [ pkgs.dmenu ];
  };

  users.groups.greeter = { };
  users.users.greeter.group = "greeter";
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "sway";
        user = "andi";
      };
      initial_session = {
        user = "andi";
        command = "sway";
      };
    };
  };

  environment.etc."sway/config.d/custom.conf".text = ''
    # Your preferred terminal emulator
    set $term ${pkgs.ate}/bin/ate
    # Start a terminal
    bindsym $mod+Return exec $term

    exec ate ${pkgs.writeShellScript "launch-tmux" ''
      ${pkgs.tmux}/bin/tmux a || ${pkgs.tmux}/bin/tmux new
    ''}
    exec kodi
  '';

  users.groups.video.members = [ "andi" ];

}
