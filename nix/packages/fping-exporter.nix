{ fetchFromGitHub
, buildGoModule
}:
buildGoModule {
  name = "fping_exporter";

  src = fetchFromGitHub {
    owner = "schweikert";
    repo = "fping-exporter";
    rev = "905e15f87adb6eab7f03b10805b4374c32ccd279";
    sha256 = "03578h893ivrrm2w3j4zwha59swxf3pwgxzq8m5libl7ibmbyi1b";
  };

  vendorSha256 = "1a47040znkgsg9qbwd8m1j3gf2ibmbn0pd1f5xvd2l32q74b3i0p";
}
