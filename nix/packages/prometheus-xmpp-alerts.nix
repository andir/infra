{ python3, fetchFromGitHub, prometheus-alertmanager }:
let
  pname = "prometheus-xmpp-alerts";
in
python3.pkgs.buildPythonApplication {
  inherit pname;
  version = "git";

  src = fetchFromGitHub {
    owner = "andir";
    repo = pname;
    rev = "500a316a83b5d72c490cb62c3e7f5aa5efc7f5bf";
    sha256 = "0lphw62g7jmgjhdxng0jfw8pb5dzc71qv5s10dxbswjhki003zpn";
  };

  propagatedBuildInputs = with python3.pkgs; [
    slixmpp
    aiohttp
    pyyaml
    prometheus_client
  ];

  checkInputs = [ python3.pkgs.pytz ];
}
