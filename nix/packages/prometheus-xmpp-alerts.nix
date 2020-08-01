{ python3, fetchFromGitHub, prometheus-alertmanager }:
let
  pname = "prometheus-xmpp-alerts";
in
python3.pkgs.buildPythonApplication {
  inherit pname;
  version = "git";

  src = fetchFromGitHub {
    owner = "jelmer";
    repo = pname;
    rev = "7ef30a86b08a006ac47cfc1d644f2167a55e538f";
    sha256 = "1cp7nijlr3r1cz5ddqkzsbaaabaafc74d53vk4n27n542hfpssn7";
  };

  postFixup = ''
    substituteInPlace $out/${python3.sitePackages}/prometheus_xmpp/__init__.py \
      --replace '"/usr/bin/amtool"' '"${prometheus-alertmanager}/bin/amtool", "--alertmanager.url",  "http://127.0.0.1:9093"' # FIXME: configure this during runtime
  '';

  propagatedBuildInputs = with python3.pkgs; [
    slixmpp
    aiohttp
    pyyaml
    prometheus_client
  ];

  checkInputs = [ python3.pkgs.pytz ];
}
