{ morph }:
let
  pkgs = import ../nix;
  shell = import ../shell.nix;
in pkgs.runCommand "shell-gc-root" {} ''
  mkdir $out
  ${pkgs.lib.concatMapStringsSep "\n" (n: "ln -s ${n} $out") shell.buildInputs}
  ln -s ${morph} $out
''
