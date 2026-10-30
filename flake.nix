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

      # Runs the installed compiler as a user would: version reporting and one
      # JIT-compiled program exercise stdlib and tcclib discovery in the store
      # layout, the failure class where builds pass but the runtime is dead.
      checks = builtins.mapAttrs (
        system: pkgs:
        {
          goose =
            pkgs.runCommand "goose-check"
              {
                nativeBuildInputs = [ inputs.self.packages.${system}.goose ];
              }
              ''
                set -e
                goose version
                printf 'fn main() {\n    print("ok");\n}\n' > smoke.goose
                [ "$(goose smoke.goose)" = ok ]
                touch $out
              '';
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
