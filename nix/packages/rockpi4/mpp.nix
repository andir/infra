{ stdenv, fetchFromGitHub, cmake }:
stdenv.mkDerivation {
  pname = "mpp";
  version = "git";

  nativeBuildInputs = [ cmake ];

  src = fetchFromGitHub {
    owner = "rockchip-linux";
    repo = "mpp";
    rev = "b0d0a5aafd328078d19455f606ddfd0f8103d7de";
    sha256 = "0bp6i95l791gfh0vs9696r5vgb36p1bks1zzaqgczq21i1wrq6pc";
  };
}
