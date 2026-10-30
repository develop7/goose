{
  description = "The Goose Programming Language";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs:
    let
      # Every system nixpkgs supports, each with its package set — the
      # template's per-system iteration, named once for all outputs.
      forAllSystems = f: builtins.mapAttrs f inputs.nixpkgs.legacyPackages;
    in
    {
      packages =
        forAllSystems (
          system: pkgs:
          let
            # The untagged-build version prefix; the snapshot-<sha7> spelling
            # is shared with the release workflow via this file.
            prefix = pkgs.lib.removeSuffix "\n" (builtins.readFile ./snapshot-version-prefix);
            goose = pkgs.stdenv.mkDerivation (finalAttrs: {
              pname = "goose";
              # Upstream releases are CalVer tags (v2026.3); the release
              # workflow builds an untagged tree as snapshot-<sha7>. A tree
              # without a Git revision reports "unknown", as cmake/version.cmake
              # does.
              version =
                if inputs.self ? shortRev then
                  "${prefix}-${inputs.self.shortRev}"
                else if inputs.self ? dirtyShortRev then
                  "${prefix}-${inputs.self.dirtyShortRev}"
                else
                  "unknown";

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
        );

      # Runs the installed compiler as a user would: version reporting and one
      # JIT-compiled program exercise stdlib and tcclib discovery in the store
      # layout, the failure class where builds pass but the runtime is dead.
      checks = forAllSystems (
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
                # Collect the run's output without shadowing $out, which is
                # the output path stdenv must produce.
                got=$(goose smoke.goose)
                [ "$got" = ok ]
                touch $out
              '';
        }
      );

      devShells = forAllSystems (
        system: pkgs:
        {
          default = pkgs.mkShell {
            inputsFrom = [ inputs.self.packages.${system}.goose ];
            # The test and sample runners need python3, and the suite runs
            # under clang (ci.yml passes --require-clang); stdenv's cc covers
            # everything else.
            packages = [
              pkgs.python3
              pkgs.clang
            ];
          };
        }
      );
    };
}
