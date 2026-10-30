{
  description = "The Goose Programming Language";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs:
    {
      packages =
        builtins.mapAttrs (
          system: pkgs:
          let
            goose = pkgs.stdenv.mkDerivation (finalAttrs: {
              pname = "goose";
              # Upstream releases are CalVer tags (v2026.3); the release
              # workflow builds an untagged tree as snapshot-<sha7>.
              version = "snapshot-${inputs.self.shortRev or "dirty"}";

              src = inputs.self;

              nativeBuildInputs = [
                pkgs.cmake
                pkgs.ninja
              ];

              cmakeFlags = [
                "-DGOOSE_VERSION=${finalAttrs.version}"
                # The TinyCC runtime stage; baked into the compiler at
                # configure time (docs/design/jit_backend.md, "Packagers can
                # set GOOSE_TCC_LIB_PATH in CMake to their installation
                # directory").
                "-DGOOSE_TCC_LIB_PATH=${placeholder "out"}/tcclib"
              ];

              installPhase = ''
                runHook preInstall
                cmake --install . --prefix "$out"
                runHook postInstall
              '';

              meta = {
                description = "Memory-safe systems programming language";
                homepage = "https://github.com/aardappel/goose";
                license = pkgs.lib.licenses.asl20;
                mainProgram = "goose";
                # cmake/libtcc.cmake configures only x86_64 and arm64.
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                  "x86_64-darwin"
                  "aarch64-darwin"
                ];
              };
            });
          in
          {
            inherit goose;
            default = goose;
          }
        ) inputs.nixpkgs.legacyPackages;

      devShells = builtins.mapAttrs (
        system: pkgs:
        {
          default = pkgs.mkShell {
            inputsFrom = [ inputs.self.packages.${system}.goose ];
            packages = [
              pkgs.python3
              pkgs.clang
            ];
          };
        }
      ) inputs.nixpkgs.legacyPackages;
    };
}
