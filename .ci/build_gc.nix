{ morph }:
let
  pkgs = import ../nix { };
  shell = import ../shell.nix;
  sources = import ../nix/sources.nix;
in
pkgs.runCommand "shell-gc-root" { } ''
  mkdir $out
  ${pkgs.lib.concatMapStringsSep "\n" (n: "ln -s ${n} $out") shell.buildInputs}
  ${pkgs.lib.concatMapStringsSep "\n" (n: "ln -s ${n} $out") (pkgs.lib.filter (n: builtins.typeOf n != "lambda") (pkgs.lib.attrValues sources))}
  ln -s ${builtins.storePath morph} $out
''
