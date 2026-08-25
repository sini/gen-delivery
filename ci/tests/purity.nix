# PURITY — the library is nixpkgs-lib-free, and this is what holds it there.
#
# gen-delivery drives gen-merge-resolved values and gen-aspects declarations with builtins only. It
# has no sanctioned nixpkgs boundary at all: the nixpkgs eval belongs to the TERMINAL, which is
# caller-supplied and lives in the caller's own repository. So there is no carve-out here and no
# classification step — every file under ../../lib is strict.
#
# The scan reads SOURCE with comment text stripped, so a token named in a comment (this file names
# several) does not fail the cell it documents.
{ lib, ... }:
let
  libDir = ../../lib;

  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  walk =
    dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          walk (dir + "/${name}")
        else if lib.hasSuffix ".nix" name then
          [ (dir + "/${name}") ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  read = p: stripComments (builtins.readFile p);

  # The nixpkgs module-system CALL tether and the nixpkgs-IMPORT tether. `evalModules` is safe to
  # forbid outright — it is not an infix of gen-merge's `evalModuleTree`.
  forbidden = [
    "lib.types"
    "lib.mkOption"
    "lib.mkMerge"
    "lib.evalModules"
    "evalModules"
    "nixpkgs"
    "{ lib }"
    "{ lib,"
  ];

  scanned = walk libDir;

  violations = lib.concatMap (
    p: map (tok: "${toString p}: '${tok}'") (lib.filter (tok: lib.hasInfix tok (read p)) forbidden)
  ) scanned;
in
{
  flake.tests.purity = {
    test-library-is-nixpkgs-free = {
      expr = violations;
      expected = [ ];
    };
    # CONTROL — the scan reached files at all. An empty `violations` over an empty file list is a
    # clean read of nothing, and it is indistinguishable from the real thing.
    test-control-scan-reached-the-library = {
      expr = builtins.length scanned > 0;
      expected = true;
    };
    # CONTROL — the predicate can fire. A forbidden token planted in a string the scan actually
    # reads is reported, so a zero above is a discrimination rather than a broken matcher.
    test-control-predicate-fires-on-a-planted-token = {
      expr = lib.filter (tok: lib.hasInfix tok "a line naming lib.types in it") forbidden;
      expected = [ "lib.types" ];
    };
  };
}
