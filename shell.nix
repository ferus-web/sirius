with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    pkg-config
    curl
    clang
    wayland
    libxkbcommon
    fontconfig
    libGL
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    curl.dev
    wayland.dev
    fontconfig.dev
    libGL.dev
    libxkbcommon.dev
  ];
}
