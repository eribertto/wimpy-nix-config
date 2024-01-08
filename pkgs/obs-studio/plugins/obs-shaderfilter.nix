{ lib
, stdenv
, fetchFromGitHub
, cmake
, obs-studio
, qtbase
}:

stdenv.mkDerivation rec {
  pname = "obs-shaderfilter";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "exeldro";
    repo = "obs-shaderfilter";
    rev = version;
    sha256 = "sha256-kjch0O9wzbxGXr8J6tUosqZe1QWQJ0LCD5+lqevq2vQ=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ obs-studio qtbase ];

  cmakeFlags = [
    "-DBUILD_OUT_OF_TREE=On"
  ];

  dontWrapQtApps = true;

  postInstall = ''
    rm -rf $out/obs-plugins
    mv $out/data $out/share/obs
  '';

  meta = with lib; {
    description = "OBS Studio filter for applying an arbitrary shader to a source.";
    homepage = "https://github.com/exeldro/obs-shaderfilter";
    maintainers = with maintainers; [ flexiondotorg ];
    license = licenses.gpl2Plus;
    platforms = [ "x86_64-linux" "i686-linux" ];
  };
}