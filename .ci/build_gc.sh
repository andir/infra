#! /usr/bin/env nix-shell
#! nix-shell ../shell.nix --pure -i bash

set -ex

# IMPURE: we rely on the host to provide a proper ca bundle
export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"

MORPH_ROOT=$(morph build config/servers.nix)
nix-build .ci/build_gc.nix --arg morph "$MORPH_ROOT" --out-link result
