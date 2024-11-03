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
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default =
            let

              baseName = "kicad-unstable";
              versionsImport = import ./versions.nix;

              # versions.nix does not provide us with version, src and rev. We
              # need to turn this into approprate fetcher calls.
              # kicadSrcFetch = fetchFromGitLab {
              #   group = "kicad";
              #   owner = "code";
              #   repo = "kicad";
              #   rev = versionsImport.${baseName}.kicadVersion.src.rev;
              #   sha256 = versionsImport.${baseName}.kicadVersion.src.sha256;
              # };

              libSrcFetch =
                name:
                pkgs.fetchFromGitLab {
                  group = "kicad";
                  owner = "libraries";
                  repo = "kicad-${name}";
                  rev = versionsImport.${baseName}.libVersion.libSources.${name}.rev;
                  sha256 = versionsImport.${baseName}.libVersion.libSources.${name}.sha256;
                };

              # use default source and version (as defined in versions.nix) by
              # default, or use the appropriate attribute from `srcs` if building
              # unstable with `srcs` properly defined.
              kicadSrc = {
                src = ./kicad;
                rev = "develop";
              };
              kicadVersion = "dev";

              libSrc = name: libSrcFetch name;
              # TODO does it make sense to only have one version for all libs?
              libVersion = versionsImport.${baseName}.libVersion.version;

              # addons
              addons = [ ];
              wxGTK = pkgs.wxGTK32;
              python = pkgs.python3;
              wxPython = python.pkgs.wxpython;
              addonPath = "addon.zip";
              addonsDrvs = map (pkg: pkg.override { inherit addonPath python; }) addons;

              addonsJoined =
                pkgs.runCommand "addonsJoined"
                  {
                    inherit addonsDrvs;
                    nativeBuildInputs = [
                      pkgs.unzip
                      pkgs.jq
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

              stable = false;
              testing = false;
              withNgspice = true;
              withScripting = true;
              withI18n = true;
              with3d = true;
              debug = true;
              sanitizeAddress = true;
              sanitizeThreads = false;
            in
            # inherit (lib)
            #   concatStringsSep
            #   flatten
            #   optionalString
            #   optionals
            #   ;
            pkgs.mkShell.override
              {
                # Override stdenv in order to change compiler:
                # stdenv = pkgs.gcc14Stdenv;
                # stdenv = pkgs.gcc;
              }
              rec {
                packages = with pkgs; [
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
                  protobuf3_20
                  # lemon

                  python311Packages.numpy # numpy
                  python311Packages.pytest
                  python311Packages.cairosvg
                  python311Packages.pytest-image-diff

                  dconf
                  librsvg
                  cups
                  gsettings-desktop-schemas
                  hicolor-icon-theme
                  gnome.adwaita-icon-theme
                  unzip
                  jq

                  gdb

                ];

                # Common libraries, referenced during runtime, via the wrapper.
                passthru.libraries = pkgs.callPackages ./libraries.nix { inherit libSrc; };
                passthru.callPackage = pkgs.newScope { inherit addonPath python; };
                system = pkgs.system;
                base = pkgs.callPackage ./base.nix {
                  inherit system;
                  inherit stable testing baseName;
                  inherit kicadSrc kicadVersion;
                  inherit wxGTK python wxPython;
                  inherit withNgspice withScripting withI18n;
                  inherit debug sanitizeAddress sanitizeThreads;
                };

                pname = "kicad-dev";
                version = builtins.substring 0 10 kicadSrc.rev;

                src = base;
                dontUnpack = true;
                dontConfigure = true;
                dontBuild = true;
                dontFixup = true;

                # lib = pkgs.lib;
                # optionals = pkgs.optionals;
                makeWrapper = pkgs.makeWrapper;
                # symlinkJoin = pkgs.symlinkJoin;
                stdenv = pkgs.stdenv;
                # optionalString = lib.strings.OptionalString;
                # flatten = pkgs.flatten;
                # concatStringsSep = pkgs.lib.concatStringsSep;

                pythonPath =
                  pkgs.lib.lists.optionals (withScripting) [
                    wxPython
                    python.pkgs.six
                    python.pkgs.requests
                  ]
                  ++ addonsDrvs;

                nativeBuildInputs = [
                  makeWrapper
                ] ++ pkgs.lib.lists.optionals (withScripting) [ python.pkgs.wrapPython ];

                # KICAD7_TEMPLATE_DIR only works with a single path (it does not handle : separated paths)
                # but it's used to find both the templates and the symbol/footprint library tables
                # https://gitlab.com/kicad/code/kicad/-/issues/14792
                template_dir = pkgs.symlinkJoin {
                  name = "KiCad_template_dir";
                  paths = with passthru.libraries; [
                    "${templates}/share/kicad/template"
                    "${footprints}/share/kicad/template"
                    "${symbols}/share/kicad/template"
                  ];
                };
                # We are emulating wrapGAppsHook3, along with other variables to the wrapper
                makeWrapperArgs =
                  with passthru.libraries;
                  [
                    "--prefix XDG_DATA_DIRS : ${base}/share"
                    "--prefix XDG_DATA_DIRS : ${pkgs.hicolor-icon-theme}/share"
                    "--prefix XDG_DATA_DIRS : ${pkgs.gnome.adwaita-icon-theme}/share"
                    "--prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
                    "--prefix XDG_DATA_DIRS : ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
                    # wrapGAppsHook3 did these two as well, no idea if it matters...
                    "--prefix XDG_DATA_DIRS : ${pkgs.cups}/share"
                    "--prefix GIO_EXTRA_MODULES : ${pkgs.dconf}/lib/gio/modules"
                    # required to open a bug report link in firefox-wayland
                    "--set-default MOZ_DBUS_REMOTE 1"
                    "--set-default KICAD8_FOOTPRINT_DIR ${footprints}/share/kicad/footprints"
                    "--set-default KICAD8_SYMBOL_DIR ${symbols}/share/kicad/symbols"
                    "--set-default KICAD8_TEMPLATE_DIR ${template_dir}"
                  ]
                  ++ pkgs.lib.lists.optionals (addons != [ ]) (
                    let
                      stockDataPath = pkgs.symlinkJoin {
                        name = "kicad_stock_data_path";
                        paths = [
                          "${base}/share/kicad"
                          "${addonsJoined}/share/kicad"
                        ];
                      };
                    in
                    [ "--set-default NIX_KICAD8_STOCK_DATA_PATH ${stockDataPath}" ]
                  )
                  ++ pkgs.lib.lists.optionals (with3d) [
                    "--set-default KICAD8_3DMODEL_DIR ${packages3d}/share/kicad/3dmodels"
                  ]
                  ++ pkgs.lib.lists.optionals (withNgspice) [ "--prefix LD_LIBRARY_PATH : ${pkgs.libngspice}/lib" ]

                  # infinisil's workaround for #39493
                  ++ [ "--set GDK_PIXBUF_MODULE_FILE ${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" ];

                # why does $makeWrapperArgs have to be added explicitly?
                # $out and $program_PYTHONPATH don't exist when makeWrapperArgs gets set?
                installPhase =
                  let
                    bin = if stdenv.hostPlatform.isDarwin then "*.app/Contents/MacOS" else "bin";
                    tools = [
                      "kicad"
                      "pcbnew"
                      "eeschema"
                      "gerbview"
                      "pcb_calculator"
                      "pl_editor"
                      "bitmap2component"
                    ];
                    utils = [
                      "dxf2idf"
                      "idf2vrml"
                      "idfcyl"
                      "idfrect"
                      "kicad-cli"
                    ];
                  in
                  (pkgs.lib.concatStringsSep "\n" (
                    pkgs.lib.lists.flatten [
                      "runHook preInstall"

                      (pkgs.lib.strings.optionalString (withScripting) "buildPythonPath \"${base} $pythonPath\" \n")

                      # wrap each of the directly usable tools
                      (map (
                        tool:
                        "makeWrapper ${base}/${bin}/${tool} $out/bin/${tool} $makeWrapperArgs"
                        + pkgs.lib.strings.optionalString (withScripting) " --set PYTHONPATH \"$program_PYTHONPATH\""
                      ) tools)

                      # link in the CLI utils
                      (map (util: "ln -s ${base}/${bin}/${util} $out/bin/${util}") utils)

                      "runHook postInstall"
                    ]
                  ));

                postInstall = ''
                  mkdir -p $out/share
                  ln -s ${base}/share/applications $out/share/applications
                  ln -s ${base}/share/icons $out/share/icons
                  ln -s ${base}/share/mime $out/share/mime
                  ln -s ${base}/share/metainfo $out/share/metainfo
                '';

                passthru.updateScript = {
                  command = [
                    ./update.sh
                    "${pname}"
                  ];
                  supportedFeatures = [ "commit" ];
                };

                meta = rec {
                  description =
                    (
                      if (stable) then
                        "Open Source Electronics Design Automation suite"
                      else if (testing) then
                        "Open Source EDA suite, latest on stable branch"
                      else
                        "Open Source EDA suite, latest on master branch"
                    )
                    + (pkgs.lib.strings.optionalString (!with3d) ", without 3D models");
                  homepage = "https://www.kicad.org/";
                  longDescription = ''
                    KiCad is an open source software suite for Electronic Design Automation.
                    The Programs handle Schematic Capture, and PCB Layout with Gerber output.
                  '';
                  license = pkgs.lib.licenses.gpl3Plus;
                  maintainers = with pkgs.lib.maintainers; [ evils ];
                  platforms = pkgs.lib.platforms.all;
                  broken = stdenv.hostPlatform.isDarwin;
                  mainProgram = "kicad";
                };

                shellHook = ''
                  export OCCT_DIR="${pkgs.opencascade-occt_7_6}"
                  # export LEMON_DIR="${pkgs.lemon}"
                '';
              };
        }
      );
    };
}
