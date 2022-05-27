{ pkgs ? import <nixpkgs> {} }:
let
  ruby = pkgs.ruby;
in
pkgs.mkShell {
  nativeBuildInputs = [
    (import ./default.nix { inherit pkgs ruby; }).wrappedRuby
  ];
}
