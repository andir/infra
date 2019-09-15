let
  pkgs = import ./nix;
in pkgs.mkShell {
  buildInputs = with pkgs; [ niv morph ];
}
