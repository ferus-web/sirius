with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    pkg-config
    curl
    clang
    wayland
    vulkan-loader
    libxkbcommon
    fontconfig
    simdutf
    gmp
    boehmgc
    libGL
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    curl.dev
    wayland.dev
    fontconfig.dev
    simdutf
    libGL.dev
    gmp.dev
    boehmgc.dev
    vulkan-loader.dev
    libxkbcommon.dev
  ];
}
