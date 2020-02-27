{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let

  haskell = pkgs.callPackage ./nix/haskell-packages.nix { };
  hsenv = haskell.packages.ghcLinear.ghcWithPackages (p: with p; []);

in

stdenv.mkDerivation {
  name = "linear-haskell-env";
  buildInputs = [ hsenv ];
  shellHook = ''
  '';
}