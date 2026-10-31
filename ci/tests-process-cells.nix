# THE PER-PROCESS CELLS (den-hoag-ien5k) — one host's artifact read in a projection of n hosts
# (`one-host-fixture.nix`), with gen-scope's `resolve` spied: each call traces `label`, which
# `tests-process.nix` counts on stderr, and the evaluator's statistics count the thunks.
#
# Verdict is a PROCESS EXIT read by `tests-process.nix` (one fixture per process). Sources arrive as
# ARGUMENTS rather than through `fetchTree`, and every dependency is rebuilt from its own `lib/` with
# explicit arguments, so the spied `scope` reaches this library through its own formal: a flake's
# precomputed `.lib` output would already be bound to an unspied one. Only this library's `scope` is
# spied; gen-merge keeps the unspied instance, so the count is this library's resolutions alone.
{
  arm,
  libSrc,
  # `one-host-fixture.nix`, copied to the store beside this file rather than imported relative to it.
  fixtureSrc,
  genPreludeSrc,
  genIdentitySrc,
  genGraphSrc,
  genAlgebraSrc,
  genScopeSrc,
  genTypesSrc,
  genMemoSrc,
  genMergeSrc,
  genSchemaSrc,
  genAspectsSrc,
  genAspectsAlgebraSrc,
  # A trace label generated fresh per run by the runner, which counts its lines on stderr.
  label ? "",
  # The fixture size, as a string (`--argstr`).
  n ? "0",
}:
let
  prelude = import "${genPreludeSrc}/lib";
  identity = import "${genIdentitySrc}/lib";
  graph = import "${genGraphSrc}/lib" { inherit prelude; };
  algebra = import "${genAlgebraSrc}/lib";
  scope = import "${genScopeSrc}/lib" {
    inherit
      algebra
      graph
      identity
      prelude
      ;
  };
  genMerge = import "${genMergeSrc}/lib" {
    inherit prelude scope;
    types = import "${genTypesSrc}/lib" { inherit algebra identity prelude; };
    memo = import "${genMemoSrc}/lib" { inherit graph prelude; };
  };
  genSchema = import "${genSchemaSrc}/lib" {
    inherit
      prelude
      algebra
      identity
      graph
      ;
    merge = genMerge;
  };
  aspects = import "${genAspectsSrc}/lib" {
    inherit prelude identity;
    algebra = import "${genAspectsAlgebraSrc}/lib";
    merge = genMerge;
    schema = genSchema;
  };
  # THE SPY: the same calculus, its `resolve` tracing `label` once per call.
  genDelivery = import libSrc {
    inherit aspects algebra prelude;
    scope = scope // {
      resolve =
        o: s: from:
        builtins.trace label (scope.resolve o s from);
    };
  };
  fixture = import fixtureSrc {
    inherit
      genDelivery
      aspects
      genMerge
      genSchema
      ;
  };
  at =
    members:
    fixture {
      n = builtins.fromJSON n;
      inherit members;
    };

  cells = {
    # One host's artifact, every host a member of `a`.
    one = (at 1).one;
    # Every host's declared members, the floor a content-decided key set reads; its value is the
    # host count.
    members = hostsIn (at 1).members;
    # The three-member arm: every host a member of `a`, `b` and `c`, where `c` includes `a`.
    one3 = (at 3).one;
    members3 = hostsIn (at 3).members;
  };
  hostsIn = m: builtins.deepSeq m (builtins.length (builtins.attrNames m));
in
builtins.deepSeq cells.${arm} cells.${arm}
