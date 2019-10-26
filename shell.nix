{ pkgs ? import <nixpkgs> {} }:

let
  env = pkgs.bundlerEnv {
    name = "ratsinfo-scraper";
    ruby = pkgs.ruby_2_6;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in

pkgs.mkShell {
  buildInputs = [ env ];
}
