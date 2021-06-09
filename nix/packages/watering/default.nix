{ stdenv, cmake, ninja, smooth, esp-idf, gcc8 }:
stdenv.mkDerivation rec {
  name = "watering-plants";
  src = ./.;
  SMOOTH_PATH = smooth;
  IDF_PATH = esp-idf;
  IDF_TOOLS_PATH = esp-idf + "/tools";
  nativeBuildInputs = [ cmake ninja gcc8 esp-idf.python ];
  shellHook = ''
    export PATH="$IDF_TOOLS_PATH:$PATH"
  '';
  hardeningDisable = [ "format" ]; # -Werror=format-security
  cmakeFlags = [ "-DESP_PLATFORM=1" "-DCMAKE_TOOLCHAIN_FILE=$IDF_PATH/tools/cmake/toolchain-esp32.cmake" ];
} /* ''
  export PATH="$IDF_TOOLS_PATH:$PATH"
  cd $(mktemp -d)
  cp -r --no-preserve=mode $src src
  mkdir build
  cd build
  cmake ../src 
  make
  ls -la
  '' */
