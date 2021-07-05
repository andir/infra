{ pkgs ? import ../.././. { } }:
let
  python = pkgs.python38;
in
(pkgs.python38Packages.buildPythonApplication {
  pname = "spacesbot";
  version = "whatever";
  src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
  format = "pyproject";
  propagatedBuildInputs = with python.pkgs; [ matrix-nio ];
  nativeBuildInputs = [ python.pkgs.poetry-core ];

  pythonImportsCheck = [ "spacesbot" ];

  installCheckPhase = ''
    $out/bin/spacesbot --help > /dev/null
  '';
})
