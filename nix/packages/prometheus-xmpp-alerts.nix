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
    rev = "a7626e7e8df2fa623875890dd183c432e6aa6d99";
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
