with import <nixpkgs> { };

let
  curlWs = curl.override {
    websocketSupport = true;
  };
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
  ];

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
