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
    libGL
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    curl.dev
    wayland.dev
    fontconfig.dev
    libGL.dev
    vulkan-loader.dev
    libxkbcommon.dev
  ];
}
