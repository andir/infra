#!/usr/bin/env nix-shell
#! nix-shell -p entr -i bash

ls -1 *.nix |entr ./runtest.sh
