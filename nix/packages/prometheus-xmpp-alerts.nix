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
    rev = "e85f483b058800fb90dc338eb84d8860c9cb4994";
    sha256 = "0qczp3mpsyhcvf62jqh8n3xcc1vjp53gic7n7mg1x97jjl5k3jmh";
  };

  propagatedBuildInputs = with python3.pkgs; [
    slixmpp
    aiohttp
    pyyaml
    prometheus_client
  ];

  checkInputs = [ python3.pkgs.pytz ];
}
