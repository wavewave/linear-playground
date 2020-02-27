{ buildPackages, pkgs, newScope }:

let
  # These are attributes in compiler and packages that don't support integer-simple.
  integerSimpleExcludes = [
  ];

  haskellLib = import (pkgs.path + "/pkgs/development/haskell-modules/lib.nix") {
    inherit (pkgs) lib;
    inherit pkgs;
  };

  callPackage = newScope {
    inherit haskellLib;
    overrides = pkgs.haskell.packageOverrides;
  };

  bootstrapPackageSet = self: super: {
    mkDerivation = drv: super.mkDerivation (drv // {
      doCheck = false;
      doHaddock = false;
      enableExecutableProfiling = false;
      enableLibraryProfiling = false;
      enableSharedExecutables = false;
      enableSharedLibraries = false;
    });
  };

  # Use this rather than `rec { ... }` below for sake of overlays.
  inherit (pkgs.haskell) compiler packages;

in {
  lib = haskellLib;

  compiler = {

    ghc863Binary = callPackage (pkgs.path + "/pkgs/development/compilers/ghc/8.6.3-binary.nix") { };

    ghcLinear = callPackage ./ghc/linear.nix {
      bootPkgs = packages.ghc863Binary;
      inherit (buildPackages.python3Packages) sphinx;
      buildLlvmPackages = buildPackages.llvmPackages_6;
      llvmPackages = pkgs.llvmPackages_6;
    };

    # The integer-simple attribute set contains all the GHC compilers
    # build with integer-simple instead of integer-gmp.
    integer-simple = let
      integerSimpleGhcNames = pkgs.lib.filter
        (name: ! builtins.elem name integerSimpleExcludes)
        (pkgs.lib.attrNames compiler);
    in pkgs.recurseIntoAttrs (pkgs.lib.genAttrs
      integerSimpleGhcNames
      (name: compiler.${name}.override { enableIntegerSimple = true; }));
  };

  # Default overrides that are applied to all package sets.
  packageOverrides = self : super : {};

  # Always get compilers from `buildPackages`
  packages = let bh = buildPackages.haskell; in {

    ghc863Binary = callPackage (pkgs.path + "/pkgs/development/haskell-modules") {
      buildHaskellPackages = bh.packages.ghc863Binary;
      ghc = bh.compiler.ghc863Binary;
      compilerConfig = callPackage (pkgs.path + "/pkgs/development/haskell-modules/configuration-ghc-8.6.x.nix") { };
      packageSetConfig = bootstrapPackageSet;
    };
    ghcLinear = callPackage (pkgs.path + "/pkgs/development/haskell-modules") {
      buildHaskellPackages = bh.packages.ghcLinear;
      ghc = bh.compiler.ghcHEAD;
      compilerConfig = callPackage ./config/linear.nix { };
    };

    # The integer-simple attribute set contains package sets for all the GHC compilers
    # using integer-simple instead of integer-gmp.
    integer-simple = let
      integerSimpleGhcNames = pkgs.lib.filter
        (name: ! builtins.elem name integerSimpleExcludes)
        (pkgs.lib.attrNames packages);
    in pkgs.lib.genAttrs integerSimpleGhcNames (name: packages.${name}.override {
      ghc = bh.compiler.integer-simple.${name};
      buildHaskellPackages = bh.packages.integer-simple.${name};
      overrides = _self : _super : {
        integer-simple = null;
        integer-gmp = null;
      };
    });

  };
}
