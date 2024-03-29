{ lib, makeWrapper, buildEnv, kodi, addons, callPackage, pkgs }:

let
  kodiPackages = callPackage (pkgs.path + /pkgs/top-level/kodi-packages.nix) { inherit kodi; };

  # linux distros are supposed to provide pillow and pycryptodome
  requiredPythonPath = with kodi.pythonPackages; makePythonPath ([ pillow pycryptodome ]);

  # each kodi addon can potentially export a python module which should be included in PYTHONPATH
  # see any addon which supplies `passthru.pythonPath` and the corresponding entry in the addons `addon.xml`
  # eg. `<extension point="xbmc.python.module" library="lib" />` -> pythonPath = "lib";
  additionalPythonPath =
    let
      addonsWithPythonPath = lib.filter (addon: addon ? pythonPath) addons;
    in
    lib.concatMapStringsSep ":" (addon: "${addon}${kodiPackages.addonDir}/${addon.namespace}/${addon.pythonPath}") addonsWithPythonPath;
in

buildEnv {
  name = "${kodi.name}-env";

  paths = [ kodi ] ++ addons;
  pathsToLink = [ "/share" ];

  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    mkdir $out/bin
    for exe in kodi{,-standalone}
    do
      makeWrapper ${kodi}/bin/$exe $out/bin/$exe \
        --prefix PYTHONPATH : ${requiredPythonPath}:${additionalPythonPath} \
        --prefix KODI_HOME : $out/share/kodi \
        --prefix LD_LIBRARY_PATH ":" "${lib.makeLibraryPath
          (lib.concatMap
            (plugin: plugin.extraRuntimeDependencies or []) addons)}"
    done

    # makeWrapper just created webinterface.default as a symlink. However,
    # kodi's webserver carefully refuses to follow symlinks, so we need to copy
    # these assets instead.
    rm $out/share/kodi/addons/webinterface.default
    cp -r ${kodi}/share/kodi/addons/webinterface.default/ $out/share/kodi/addons/webinterface.default
  '';
}
