{ pkgs ? import <nixpkgs> {}
, ruby ? pkgs.ruby
}:
with pkgs;
let
  env = bundlerEnv rec {
    name = "oparl-scraper";
    inherit ruby;
    # Update with:
    #   nix-shell -p bundler --run 'bundle lock --update'
    #   nix-shell -p bundix --run 'bundix --magic'
    gemdir = ./.;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in stdenv.mkDerivation {
  name = "oparl-scraper";
  buildInputs = [ env.wrappedRuby ];
  buildCommand = ''
    install -D -m755 ${./scrape.rb} $out/bin/scrape
    install -D -m755 ${./files_extract.rb} $out/bin/files_extract
    install -D -m755 ${./meetings2ics.rb} $out/bin/meetings2ics
    patchShebangs $out/bin/*
  '';
  passthru = { inherit (env) wrappedRuby; };
}
