{
  description = "Jellyfin2Samsung-CrossOS (binary build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        rid =
          if pkgs.stdenv.isDarwin then
            (if pkgs.stdenv.isAarch64 then "osx-arm64" else "osx-x64")
          else
            "linux-x64";
        tizenSdbPkg = pkgs.lib.attrByPath [ "tizen-sdb" ] null pkgs;
        dotnetPackage = pkgs.buildDotnetModule {
          pname = "jellyfin2samsung";
          version = "0.0.0";

          src = ./.;
          projectFile = "Jellyfin2Samsung-CrossOS/Jellyfin2Samsung.csproj";

          dotnet-sdk = pkgs.dotnet-sdk_8;
          dotnet-runtime = pkgs.dotnet-runtime_8;
          nugetDeps = ./nix/nuget-deps.nix;

          nativeBuildInputs = [ pkgs.makeWrapper ];
          configuration = "Release";
          selfContainedBuild = true;
          runtimeIdentifier = rid;
          dotnetPublishFlags = [
            "/p:PublishSingleFile=true"
            "/p:SelfContained=true"
            "/p:UseAppHost=true"
          ];

          postInstall = ''
            mkdir -p $out/bin
            target=""
            for candidate in \
              "$out/lib/jellyfin2samsung/Jellyfin2Samsung" \
              "$out/lib/Jellyfin2Samsung" \
              "$out/lib/Jellyfin2Samsung.app/Contents/MacOS/Jellyfin2Samsung"; do
              if [ -f "$candidate" ]; then
                target="$candidate"
                break
              fi
            done

            if [ -n "$target" ]; then
              rm -f "$out/bin/Jellyfin2Samsung"
              wrap_args=()
              ${pkgs.lib.optionalString (tizenSdbPkg != null) ''
                wrap_args+=(--set JELLYFIN2SAMSUNG_SDB ${tizenSdbPkg}/bin/sdb)
              ''}
              ${pkgs.lib.optionalString (pkgs.stdenv.isLinux) ''
                wrap_args+=(--set JELLYFIN2SAMSUNG_NIX_LD ${pkgs.stdenv.cc.bintools.dynamicLinker})
                wrap_args+=(--set JELLYFIN2SAMSUNG_NIX_LD_LIBRARY_PATH ${pkgs.lib.makeLibraryPath [ pkgs.zlib pkgs.openssl pkgs.stdenv.cc.cc.lib ]})
                wrap_args+=(--set JELLYFIN2SAMSUNG_SDB_OFFLINE 1)
              ''}
              makeWrapper "$target" "$out/bin/Jellyfin2Samsung" "''${wrap_args[@]}"
            fi
          '';

          postFixup = pkgs.lib.optionalString (pkgs.stdenv.isLinux) ''
            wrapper="$out/bin/Jellyfin2Samsung"
            if [ -f "$wrapper" ] && head -n 1 "$wrapper" | grep -q "bash"; then
              if ! grep -q "JELLYFIN2SAMSUNG_NIX_LD" "$wrapper"; then
                tmp="$wrapper.tmp"
                {
                  IFS= read -r first
                  printf '%s\n' "$first"
                  echo "export JELLYFIN2SAMSUNG_NIX_LD=${pkgs.stdenv.cc.bintools.dynamicLinker}"
                  echo "export JELLYFIN2SAMSUNG_NIX_LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.zlib pkgs.openssl pkgs.stdenv.cc.cc.lib ]}"
                  echo "export JELLYFIN2SAMSUNG_SDB_OFFLINE=1"
                  cat
                } < "$wrapper" > "$tmp"
                mv "$tmp" "$wrapper"
                chmod +x "$wrapper"
              fi
            fi
          '';
        };
      in
      {
        packages.default = dotnetPackage;
        packages.fetch-deps = dotnetPackage.passthru.fetch-deps;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.dotnet-sdk_8
          ];
        };

        apps.fetch-deps = {
          type = "app";
          program = "${dotnetPackage.passthru.fetch-deps}";
        };
      }
    );
}
