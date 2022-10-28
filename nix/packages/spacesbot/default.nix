{ pkgs ? import ../.././. { } }:
let
  python = pkgs.fastPython3;
in
(python.pkgs.buildPythonApplication {
  pname = "spacesbot";
  version = "whatever";
  src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
  format = "pyproject";
  propagatedBuildInputs = with python.pkgs; [ matrix-nio jinja2 ];
  nativeBuildInputs = [ python.pkgs.poetry-core ];

  pythonImportsCheck = [ "spacesbot" ];

  installCheckPhase = ''
    $out/bin/spacesbot --help > /dev/null
  '';
})
