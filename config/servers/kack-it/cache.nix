let
  cacheDir = "/var/cache/nginx/nix-binary-cache";
in
{
  systemd.tmpfiles.rules = [
    "d ${cacheDir} 0711 nginx nginx"
  ];
  systemd.services.nginx.serviceConfig.ReadWritPaths = [ cacheDir ];
  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      proxy_cache_path ${cacheDir} levels=1:2 keys_zone=cachecache:100m max_size=10g inactive=60m use_temp_path=off;
      map $status $cache_header {
        200 "public";
        302 "public";
        default "no-cache";
      } 
    '';

    virtualHosts."cache.h4ck.space" = {
      enableACME = true;
      forceSSL = true;
      locations."@fallback" = {
        proxyPass = "https://cache.zeta.h4ck.space";
        extraConfig = ''
          proxy_cache cachecache;
          proxy_cache_valid 200 302 120m;
          expires max;
          add_header Cache-Control $cache_header always;
        '';
      };
      locations."/nix-cache-info" = {
        proxyPass = "https://cache.zeta.h4ck.space";
        extraConfig = ''
          proxy_cache cachecache;
          proxy_cache_valid 200 302 60m;
          expires max;
          add_header Cache-Control $cache_header always;
        '';
      };
      locations."/" = {
        root = cacheDir;
        extraConfig = ''
          expires max;
          add_header Cache-Control $cache_header always;
          # redirect 404's to upstream, fetches from upstream if cache miss
          error_page 404 = @fallback;
        '';
      };
    };
  };
}
