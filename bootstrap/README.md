# Bootstrap a target via cloud-init

```
hcloud server create --user-data-from-file $(nix-build --no-out-link) --name test --image debian-10 --type cx11
```
