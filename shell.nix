with import <nixpkgs> { };

let
  curlWs = curl.override {
    websocketSupport = true;
  };

  mingw = pkgsCross.mingwW64;
in
mkShell {
  nativeBuildInputs = [
    pkg-config
    curlWs
    clang
    wayland
    vulkan-loader
    libxkbcommon
    fontconfig
    simdutf
    gmp
    boehmgc
    libGL
    harfbuzz
    fribidi

    # TODO: Fix figdraw's hard dependency on these
    libX11
    libxcb
    libxcursor
    libxkbcommon
    libxrender

    # browser shell
    gtk4
    libadwaita

    # cross compilation for windows builds
    mingw.buildPackages.gcc
    mingw.buildPackages.binutils
  ];

  # HACK: Is there a better way to expose these to MingW without having to define them over and over again?
  MINGW_PTHREADS = "${mingw.windows.pthreads}";
  MINGW_GMP = "${mingw.gmp}";
  MINGW_GC = "${mingw.boehmgc}";
  MINGW_SIMDUTF = "${mingw.simdutf}";

  shellHook = ''
    export CROSS_LDFLAGS="-L$MINGW_PTHREADS/lib -L$MINGW_GMP/lib -L$MINGW_GC/lib -L$MINGW_SIMDUTF/lib"
  '';

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    curlWs.dev
    wayland.dev
    fontconfig.dev
    simdutf
    libGL.dev
    gmp.dev
    boehmgc.dev
    harfbuzz.dev
    fribidi.dev
    vulkan-loader.dev
    libxkbcommon.dev
    libX11.dev
    libxcb.dev
    libxcursor.dev
    libxrender.dev
    libxkbcommon.dev
    gtk4.dev
    libadwaita.dev
  ];
}
