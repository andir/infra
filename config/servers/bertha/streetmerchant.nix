{ pkgs, ... }:
{
  systemd.services.streetmerchant = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      export PAGE_TIMEOUT=180000
      export DESKTOP_NOTIFICATIONS="1"
      export OPEN_BROWSER="false"
      export SCREENSHOT="false"
      export STORES="alternate,amd-de,alternate-nl,caseking,cyberport,asus-de,computeruniverse,equippr,evga-eu,futurex,galaxus,gamestop-de,medimax,mindfactory,otto,pcking,proshop-de,spielegrotte"
      export SHOW_ONLY_SERIES="rx6900xt,rx6800xt,rx6800xt,3090"
      #export SHOW_ONLY_SERIES="rx6700xt"
      export MAX_PRICE_SERIES_3090="800"
      export MAX_PRICE_SERIES_RX6900XT="1100"
      export MAX_PRICE_SERIES_RX6800="700"
      export MAX_PRICE_SERIES_RX6800XT="700"
      export MAX_PRICE_SERIES_RX6700XT="800"
      export PROXY_PROTOCOL="socks5"
      export PROXY_ADDRESS="172.20.71.254"
      export PROXY_PORT="1080"
      export RESTART_TIME="3600000"

      exec ${pkgs.streetmerchant}/bin/streetmerchant
    '';
    serviceConfig = {
      DynamicUser = true;
      User = "streetmerchant";
      StateDirectory = "streetmerchant";
      RuntimeDirectory = "streetmerchant";
    };
  };
}
