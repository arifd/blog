{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      version = "0.17.0";
      sources = {
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-Cs8EneLu5P/jj0yRobb+s2ooyWop/HVI9SirrO/cZX4=";
        };

        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-TCf5aJ/mMnUtlH4b1KHOw8rXqHYP4p5bETKk9ALw2iQ=";
        };
      };
      systems = builtins.attrNames sources;
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
    in
    {
      packages = forAllSystems (
        pkgs: system:
        let
          source = sources.${system};
        in
        rec {
          dodeca = pkgs.stdenv.mkDerivation {
            pname = "dodeca";
            inherit version;

            src = pkgs.fetchurl {
              url = "https://github.com/bearcove/dodeca/releases/download/v${version}/dodeca-${source.target}.tar.xz";
              inherit (source) hash;
            };

            nativeBuildInputs = [
              pkgs.xz
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.autoPatchelfHook
            ];

            buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.stdenv.cc.cc.lib
            ];

            unpackPhase = ''
              runHook preUnpack
              mkdir extracted
              tar -xJf "$src" -C extracted
              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/bin"

              binary=$(find extracted -type f -name ddc -print -quit)
              test -n "$binary"
              install -m755 "$binary" "$out/bin/ddc"

              assets=$(find extracted -type d -name dodeca-assets -print -quit)
              if [ -n "$assets" ]; then
                cp -R "$assets" "$out/bin/dodeca-assets"
              fi

              runHook postInstall
            '';

            meta = {
              description = "Dodeca static site generator";
              homepage = "https://github.com/bearcove/dodeca";
              mainProgram = "ddc";
              platforms = systems;
            };
          };

          default = dodeca;
        }
      );

      devShells = forAllSystems (
        pkgs: system: {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.dodeca
            ];
          };
        }
      );
    };
}
