{ fetchNuGet }:
let
  jsonPath = ./nuget-deps.json;
  deps =
    if builtins.pathExists jsonPath then
      builtins.fromJSON (builtins.readFile jsonPath)
    else
      builtins.throw ''
        nix/nuget-deps.json is missing.

        Generate it with:
          nix run .#fetch-deps -- nix/nuget-deps.json
      '';
in
map fetchNuGet deps
