{ fetchFromGitLab, ... }:

{
  description = "Kicad Nix-flake-based C/C++ development environment";

  # inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        # "aarch64-linux"
        # "x86_64-darwin"
        # "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f { pkgs = import nixpkgs { inherit system; }; });
      stable = false;
      srcs = { };

    in
    {
      devShells = forEachSupportedSystem (
        {
          lib,
          pkgs,
          runCommand,
        }:
        {
          default =
            pkgs.mkShell.override
              {
                # Override stdenv in order to change compiler:
                # stdenv = pkgs.gcc14Stdenv;
                # stdenv = pkgs.gcc;
              }
              rec {
                packages =
                  with pkgs;
                  [
                    # gcc14Stdenv
                    # stdenv
                    gcc
                    clang-tools
                    cmake
                    ninja
                    codespell
                    # conan
                    cppcheck
                    doxygen
                    gtest
                    lcov
                    # vcpkg
                    # vcpkg-tool

                    stdenv
                    cmake
                    libGLU
                    libGL
                    zlib
                    wxGTK32
                    gtk3
                    xorg.libX11
                    gettext
                    glew
                    glm
                    cairo
                    curl
                    openssl
                    boost
                    pkg-config
                    graphviz
                    pcre
                    xorg.libpthreadstubs
                    xorg.libXdmcp
                    unixODBC
                    libgit2
                    libsecret
                    libgcrypt
                    libgpg-error
                    fontconfig

                    util-linux
                    libselinux
                    libsepol
                    libthai
                    libdatrie
                    libxkbcommon
                    libepoxy
                    dbus
                    at-spi2-core
                    xorg.libXtst
                    pcre2
                    libdeflate

                    swig4
                    python311
                    python311Packages.wxpython
                    #wxPython
                    # python3.pkgs.wxpython
                    # python311Packages.wxpython
                    # opencascade-occt
                    opencascade-occt_7_6
                    libngspice
                    valgrind
                    protobuf
                    # lemon

                    python311Packages.numpy # numpy
                    python311Packages.pytest
                    python311Packages.cairosvg
                    python311Packages.pytest-image-diff

                    # adwaita-icon-theme
                    dconf
                    librsvg
                    cups
                    gsettings-desktop-schemas
                    hicolor-icon-theme
                    unzip
                    jq

                  ]
                  ++ (if system == "aarch64-darwin" then [ ] else [ gdb ]);

                shellHook = ''
                  export OCCT_DIR="${pkgs.opencascade-occt_7_6}"
                  # export LEMON_DIR="${pkgs.lemon}"
                '';

                baseName = "kicad-unstable";
                versionsImport = import ./versions.nix;
                libSrcFetch =
                  name:
                  fetchFromGitLab {
                    group = "kicad";
                    owner = "libraries";
                    repo = "kicad-${name}";
                    rev = versionsImport.${baseName}.libVersion.libSources.${name}.rev;
                    sha256 = versionsImport.${baseName}.libVersion.libSources.${name}.sha256;
                  };

                # only override `src` or `version` if building `kicad-unstable` with
                # the appropriate attribute defined in `srcs`.
                srcOverridep = attr: (!stable && builtins.hasAttr attr srcs);

                # use default source and version (as defined in versions.nix) by
                # default, or use the appropriate attribute from `srcs` if building
                # unstable with `srcs` properly defined.
                kicadSrc = srcs.kicad;
                kicadVersion =
                  if srcOverridep "kicadVersion" then
                    srcs.kicadVersion
                  else
                    versionsImport.${baseName}.kicadVersion.version;

                libSrc = name: if srcOverridep name then srcs.${name} else libSrcFetch name;
                # TODO does it make sense to only have one version for all libs?
                libVersion =
                  if srcOverridep "libVersion" then
                    srcs.libVersion
                  else
                    versionsImport.${baseName}.libVersion.version;

                wxGTK = packages.wxGTK32;
                python = packages.python3;
                wxPython = python.pkgs.wxpython;
                addonPath = "addon.zip";
                addons = [ ];
                addonsDrvs = map (pkg: pkg.override { inherit addonPath python; }) addons;

                addonsJoined =
                  runCommand "addonsJoined"
                    {
                      inherit addonsDrvs;
                      nativeBuildInputs = [
                        packages.unzip
                        packages.jq
                      ];
                    }
                    ''
                      mkdir $out

                      for pkg in $addonsDrvs; do
                        unzip $pkg/addon.zip -d unpacked

                        folder_name=$(jq .identifier unpacked/metadata.json --raw-output | tr . _)
                        for d in unpacked/*; do
                          if [ -d "$d" ]; then
                            dest=$out/share/kicad/scripting/$(basename $d)/$folder_name
                            mkdir -p $(dirname $dest)

                            mv $d $dest
                          fi
                        done
                        rm -r unpacked
                      done
                    '';

                inherit (lib)
                  concatStringsSep
                  flatten
                  optionalString
                  optionals
                  ;
              };
        }
      );
    };
}
