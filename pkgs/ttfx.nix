# ttfx — terminal text effects engine (Rust port of terminaltexteffects).
# Powers the screensaver: animates the NixOS ascii art with random effects.
# Packaged from source because upstream ships no release binaries.
{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "ttfx";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "omacom-io";
    repo = "ttfx";
    rev = "v${version}";
    hash = "sha256-bwFjC6ZkZibkgXjoYVH2VuqqeXklGR9kmRl2fTitWBU=";
  };

  cargoHash = "sha256-DNrg12MNqBcQi6yvoJObM1gtE90iGBCxeQ3RwueYCE4=";

  meta = with lib; {
    description = "Terminal text effects — single static Rust port of terminaltexteffects";
    homepage = "https://github.com/omacom-io/ttfx";
    license = licenses.mit;
    mainProgram = "ttfx";
  };
}
