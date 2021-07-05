# Some bits and pieces that should eventually be displayed on a website.
let
  faq = {
    "Failed to authenticate: github: user ... not in required orgs or teams" = ''
      Make sure you have set your GitHub organization membership status to public.
    '';
  };
in
{ pkgs, ... }:
{
  services.nginx.virtualHosts."nixos.dev" = {
    locations."/".root = toString pkgs.nixos-dev-website;
  };
}
