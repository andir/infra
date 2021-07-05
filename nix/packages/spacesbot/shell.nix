let pkgs = import ../../. { }; in
pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.poetry
    pkgs.black
    pkgs.python38
    pkgs.python38.pkgs.matrix-nio
  ];
}
