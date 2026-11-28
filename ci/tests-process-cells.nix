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
    # den-hoag-xwcy6: the relay arms read at depth (`forward-relay-stack` and `forward-relay-flat` in
    # `tests-process.nix`), each over `forward-fixture.nix`, every W1 hop at the root unless named. A
    # succeeding arm's value is the depth; a refusing arm's read is unguarded, so its refusal text reaches
    # stderr.
    occRelay = relay.deep (
      relay.realizedOf {
        cells = relay.cellsN;
        routes.c = {
          t1 = [ (relay.w1 0 [ ] { }) ];
        }
        // relay.atHops 1 (i: [ (relay.occR i "own") ]);
      } (relay.tn relay.d)
    );
    shortcutDag = relay.deep (
      relay.realizedOf {
        cells = relay.cellsN // {
          tz = relay.own "tz";
        };
        routes.c = relay.chain [ ] // {
          tz = map (
            i:
            relay.fx.route {
              name = "z${toString i}";
              order = [ i ];
              from = {
                class = "c";
                node = relay.tn i;
              };
              select = "cell";
              path = [ ];
            }
          ) (builtins.genList (i: i) (relay.d + 1));
        };
      } "tz"
    );
    # the foot hop reads `captured`, so its probe refuses and every cell above falls back
    captureFoot = relay.deep (
      relay.force (
        (relay.wrapperOf (relay.run {
          cells = relay.cellsN;
          routes.c = relay.chain [ ] // {
            t1 = [
              (relay.w1 0 [
                {
                  captured = "node";
                  path = [ "name" ];
                }
              ] { })
            ];
          };
        }) (relay.tn relay.d))
          { }
      )
    );
    # an item-level placement fault at the foot
    refusingRelay = relay.deep (
      relay.realizedOf {
        cells = relay.cellsN;
        routes.c = relay.chain [ ] // {
          t1 = [ (relay.w1 0 [ { scope = "nope"; } ] { }) ];
        };
      } (relay.tn relay.d)
    );
    # an occurrence relay selecting a key t0 neither declares nor receives
    refusingKeyRelay = relay.deep (
      relay.realizedOf {
        cells = relay.cellsN;
        routes.c = relay.atHops 1 (i: [ (relay.occR i "nope") ]);
      } (relay.tn relay.d)
    );
    # a list-level fault at the foot: t1 holds h0 twice
    duplicateRelay = relay.deep (
      relay.realizedOf {
        cells = relay.cellsN;
        routes.c = relay.chain [ ] // {
          t1 = [
            (relay.w1 0 [ ] { })
            (relay.w1 0 [ ] { order = [ 1 ]; })
          ];
        };
      } (relay.tn relay.d)
    );
    # `check` and the diagnostics, the `refusing` walk over every target
    checkRelay =
      let
        r = relay.run {
          cells = relay.cellsN;
          routes.c = relay.chain [ ];
        };
      in
      relay.deep {
        inherit (r) check;
        inherit (r.diagnostics) cycles affected refusing;
      };
    # the controls: d-deep non-tail recursion (one frame per hop) and its foldl' twin (none)
    twinCtl =
      let
        f = i: if i == 0 then [ (relay.hop 0) ] else f (i - 1) ++ [ (relay.hop i) ];
      in
      relay.deep (f relay.d);
    twinFold = relay.deep (
      builtins.foldl' (acc: i: acc ++ [ (relay.hop i) ]) [ ] (builtins.genList (i: i) (relay.d + 1))
    );
  };
  relay = rec {
    d = builtins.fromJSON n;
    fx = import forwardFixtureSrc {
      inherit genDelivery;
      lib = import "${nixpkgsSrc}/lib";
    };
    tn = i: "t${toString i}";
    own = t: {
      c = [
        [
          "own"
          (fx.own t)
        ]
      ];
    };
    cellsN = builtins.listToAttrs (
      map (i: {
        name = tn i;
        value = own (tn i);
      }) (builtins.genList (i: i) (d + 1))
    );
    w1 =
      i: path: extra:
      fx.route (
        {
          name = "h${toString i}";
          order = [ 0 ];
          from = {
            class = "c";
            node = tn i;
          };
          select = "cell";
          inherit path;
        }
        // extra
      );
    occR =
      i: id:
      fx.route {
        name = "q${toString i}";
        order = [ 0 ];
        from = {
          class = "c";
          node = tn i;
        };
        select = fx.occ "t0" "c" id;
        path = [ ];
      };
    # t(i+1) <- routes i, for i from `lo` to d - 1
    atHops =
      lo: routes:
      builtins.listToAttrs (
        map (i: {
          name = tn (i + 1);
          value = routes i;
        }) (builtins.genList (i: i + lo) (d - lo))
      );
    chain = path: atHops 0 (i: [ (w1 i path { }) ]);
    run = s: fx.run ({ extraTerminals.s = _: null; } // s);
    realizedOf = s: t: (run s).realized.c.${t};
    wrapperOf =
      r: t:
      builtins.elemAt r.projected.nodes.${t}.classes.c (
        builtins.length r.projected.nodes.${t}.classes.c - 1
      );
    force =
      v:
      if builtins.isFunction v then
        force (v { })
      else if builtins.isList v then
        map force v
      else if builtins.isAttrs v then
        builtins.mapAttrs (_: force) v
      else
        v;
    hop = i: {
      k = i;
      v = "own-${toString i}";
    };
    deep = v: builtins.deepSeq v d;
  };
  hostsIn = m: builtins.deepSeq m (builtins.length (builtins.attrNames m));
in
builtins.deepSeq cells.${arm} cells.${arm}
