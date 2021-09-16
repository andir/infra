{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ate
    firefox
    (kodi-wayland.withPackages (p: with p; [
      netflix
      pvr-iptvsimple
    ]))
  ];

  networking.firewall.extraStopCommands = ''
    iptables -D INPUT -p tcp --dport 8080 -s 172.20.23.0/24 -j ACCEPT || : # kodi
    ip6tables -D INPUT -p tcp --dport 8080 -s fd21:a07e:735e:ff00::/64 -j ACCEPT  || # kodi
  '';

  networking.firewall.extraCommands = ''
    iptables -I INPUT 1 -p tcp --dport 8080 -s 172.20.23.0/24 -j ACCEPT || : # kodi
    ip6tables -I INPUT 1 -p tcp --dport 8080  -s fd21:a07e:735e:ff00::/64 -j ACCEPT  || # kodi
  '';


  programs.sway = {
    enable = true;
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
