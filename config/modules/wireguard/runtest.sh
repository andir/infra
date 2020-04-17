#! /usr/bin/env nix-shell
#! nix-shell -p nix -p jq -i bash

nix eval '(import ./test.nix {})' --json | jq
