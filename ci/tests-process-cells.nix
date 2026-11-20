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
  # `forward-fixture.nix` and nixpkgs, whose module system is its receiver (the `width` arm only).
  forwardFixtureSrc ? null,
  nixpkgsSrc ? null,
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
    inherit
      aspects
      algebra
      prelude
      graph
      ;
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
    # Every host's artifact read; its value is the host count.
    every = hostsIn (at 1).every;
    # den-hoag-lrnaw: `forward`'s bucket width, n routes from n producers into ONE target, its
    # delivery and `check` forced; its value is the route count.
    width =
      let
        k = builtins.fromJSON n;
        fx = import forwardFixtureSrc {
          inherit genDelivery;
          lib = import "${nixpkgsSrc}/lib";
        };
        ix = builtins.genList (i: toString i) k;
        r = fx.run {
          cells = {
            t0.c = [
              [
                "own"
                (fx.own "t0")
              ]
            ];
          }
          // builtins.listToAttrs (
            map (i: {
              name = "p${i}";
              value.s = [
                [
                  "o${i}"
                  (fx.t "X${i}")
                ]
              ];
            }) ix
          );
          routes.c.t0 = map (
            i:
            fx.route {
              name = "g${i}";
              order = [ (builtins.fromJSON i) ];
              from = {
                class = "s";
                node = "p${i}";
              };
            }
          ) ix;
          extraTerminals.s = _: null;
        };
      in
      builtins.deepSeq [ r.realized.c.t0 r.check ] k;
    # den-hoag-92bpu: `forward`'s relay depth, a W1 chain t0 -> ... -> tn at the root (`importsAt [ ]`), its
    # deepest target alone realized (`check` not forced); its value is the depth.
    depth =
      let
        d = builtins.fromJSON n;
        fx = import forwardFixtureSrc {
          inherit genDelivery;
          lib = import "${nixpkgsSrc}/lib";
        };
        tn = i: "t${toString i}";
        ix = builtins.genList (i: i) d;
        r = fx.run {
          cells = builtins.listToAttrs (
            map (i: {
              name = tn i;
              value.c = [
                [
                  "own"
                  (fx.own (tn i))
                ]
              ];
            }) (ix ++ [ d ])
          );
          routes.c = builtins.listToAttrs (
            map (i: {
              name = tn (i + 1);
              value = [
                (fx.route {
                  name = "h${toString i}";
                  order = [ 0 ];
                  from = {
                    class = "c";
                    node = tn i;
                  };
                  select = "cell";
                  path = [ ];
                })
              ];
            }) ix
          );
        };
      in
      builtins.deepSeq r.realized.c.${tn d} d;
    # den-hoag-wk4in: `forward`'s merge depth, the twin ladder l0 .. ld, each l(i+1) with TWO W1 routes from
    # l(i) at the root (producers a and b), its deepest target alone realized; its value is the depth.
    ladder =
      let
        d = builtins.fromJSON n;
        fx = import forwardFixtureSrc {
          inherit genDelivery;
          lib = import "${nixpkgsSrc}/lib";
        };
        ln = i: "l${toString i}";
        ix = builtins.genList (i: i) d;
        hop =
          p: o: i:
          fx.route {
            name = "${p}${toString i}";
            producer = p;
            order = [ o ];
            from = {
              class = "c";
              node = ln i;
            };
            select = "cell";
            path = [ ];
          };
        r = fx.run {
          cells = builtins.listToAttrs (
            map (i: {
              name = ln i;
              value.c = [
                [
                  "own"
                  (fx.own (ln i))
                ]
              ];
            }) (ix ++ [ d ])
          );
          routes.c = builtins.listToAttrs (
            map (i: {
              name = ln (i + 1);
              value = [
                (hop "a" 0 i)
                (hop "b" 1 i)
              ];
            }) ix
          );
        };
      in
      builtins.deepSeq r.realized.c.${ln d} d;
    # den-hoag-wk4in: a merge through DISTINCT relay cells per level, l(i) -> x(i), y(i) -> l(i+1), every
    # route W1 at the root, its deepest target alone realized; its value is the depth.
    mergeDepth =
      let
        d = builtins.fromJSON n;
        fx = import forwardFixtureSrc {
          inherit genDelivery;
          lib = import "${nixpkgsSrc}/lib";
        };
        ln = i: "l${toString i}";
        ix = builtins.genList (i: i) d;
        w1 =
          name: o: from:
          fx.route {
            inherit name;
            order = [ o ];
            from = {
              class = "c";
              node = from;
            };
            select = "cell";
            path = [ ];
          };
        own = t: {
          name = t;
          value.c = [
            [
              "own"
              (fx.own t)
            ]
          ];
        };
        r = fx.run {
          cells = builtins.listToAttrs (
            map (i: own (ln i)) (ix ++ [ d ])
            ++ builtins.concatMap (i: [
              (own "x${toString i}")
              (own "y${toString i}")
            ]) ix
          );
          routes.c = builtins.listToAttrs (
            builtins.concatMap (
              i:
              let
                si = toString i;
              in
              [
                {
                  name = "x${si}";
                  value = [ (w1 "x${si}" 0 (ln i)) ];
                }
                {
                  name = "y${si}";
                  value = [ (w1 "y${si}" 0 (ln i)) ];
                }
                {
                  name = ln (i + 1);
                  value = [
                    (w1 "a${si}" 0 "x${si}")
                    (w1 "b${si}" 1 "y${si}")
                  ];
                }
              ]
            ) ix
          );
        };
      in
      builtins.deepSeq r.realized.c.${ln d} d;
  };
  hostsIn = m: builtins.deepSeq m (builtins.length (builtins.attrNames m));
in
builtins.deepSeq cells.${arm} cells.${arm}
