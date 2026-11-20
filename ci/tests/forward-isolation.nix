# `forward` sibling isolation and total diagnostics (g3p6r, ovt5a): a route-check failure is scoped
# to what is read. Values only; the refusal texts are in `../tests-error-forward.nix`.
{ genDelivery, lib, ... }:
let
  fx = import ../forward-fixture.nix { inherit genDelivery lib; };
  inherit (fx)
    route
    run
    own
    t
    ;
  s = node: {
    class = "s";
    inherit node;
  };
  c = node: {
    class = "c";
    inherit node;
  };
  thread = r: n: r.realized.c.${n}.${n}.thread;
  caught = v: if (builtins.tryEval (builtins.deepSeq v null)).success then "ADMITTED" else "CAUGHT";
  good =
    i:
    route {
      name = "g${toString i}";
      order = [ i ];
      from = s "p${toString i}";
    };
  tgt = node: {
    ${node}.c = [
      [
        "own"
        (own node)
      ]
    ];
  };
  # ONLY p0 and p1 carry `s` content, so nothing is left undelivered by construction (the clean witness).
  srcs2 = lib.genAttrs [ "p0" "p1" ] (p: {
    s = [
      [
        "o${p}"
        (t "X${p}")
      ]
    ];
  });
  # `s` has NO terminal: C2 strips and realize's root content check runs on every read.
  two =
    bad:
    run {
      cells = tgt "t0" // tgt "t1" // srcs2;
      routes.c = {
        t0 = [ (good 0) ];
        t1 = [ bad ];
      };
    };
  three =
    bad:
    run {
      cells = tgt "t0" // tgt "t1" // tgt "t2" // srcs2;
      routes.c = {
        t0 = [ (good 0) ];
        t1 = [ (good 1) ];
        t2 = [ bad ];
      };
    };
  cyc =
    y4extra: t1:
    run {
      cells = tgt "t0" // tgt "t1" // tgt "t3" // tgt "t4" // srcs2;
      routes.c = {
        t0 = [ (good 0) ];
        t3 = [
          (route {
            name = "y3";
            order = [ 0 ];
            from = c "t4";
            select = "cell";
            path = [ ];
          })
        ];
        t4 = [
          (route {
            name = "y4";
            order = [ 0 ];
            from = c "t3";
            select = "cell";
            path = [ ];
          })
        ]
        ++ y4extra;
      }
      // (if t1 == null then { } else { t1 = [ t1 ]; });
      extraTerminals.s = _: null;
    };
  badOrder = (good 1) // {
    order = "late";
  };
in
{
  flake.tests.forward-isolation = {
    # I1 (first-slice §2.5 item 6, §2.7): a malformed route into sibling t1 (a bad `order`; an undeclared key)
    # leaves t0 usable when the source class has no terminal; t1 still refuses. RED (110fb4f): every read
    # refuses with t1's route text.
    test-sibling-malformed-route-leaves-a-target-of-a-terminal-less-source-usable = {
      expr = {
        order = thread (two badOrder) "t0";
        key = thread (two ((good 1) // { colour = "red"; })) "t0";
        sibling = caught (two badOrder).realized.c.t1;
        strip = builtins.length (two badOrder).projected.nodes.p0.classes.s;
      };
      expected = {
        order = "Xp0\nR";
        key = "Xp0\nR";
        sibling = "CAUGHT";
        strip = 0;
      };
    };
    # I2: a route whose source cannot be placed (an absent node; a bogus `select` at a consumed cell; a `from`
    # that is not a record) consumes nothing and reaches no read whose stripping leaves nothing behind. RED:
    # 110fb4f and the iso2 arm (the route's check runs on every stripping) refuse t0 and t1 with t2's text.
    test-unplaceable-sibling-route-reaches-no-fully-consumed-read = {
      expr =
        map
          (
            bad:
            let
              r = three bad;
            in
            [
              (thread r "t0")
              (thread r "t1")
              (caught r.realized.c.t2)
            ]
          )
          [
            (
              (good 2)
              // {
                from = (s "nowhere") // {
                  select = "declared";
                };
              }
            )
            (
              (good 2)
              // {
                from = (s "p1") // {
                  select = "bogus";
                };
              }
            )
            ((good 2) // { from = "p1"; })
          ];
      expected = lib.genList (_: [
        "Xp0\nR"
        "Xp1\nR"
        "CAUGHT"
      ]) 3;
    };
    # D1 (ovt5a): diagnostics stay data beside a malformed route, in a sibling bucket and in a cyclic route's
    # own bucket. RED (110fb4f): `cycles` and `affected` throw the malformed route's text.
    test-diagnostics-report-a-cycle-beside-a-malformed-route = {
      expr = map (r: { inherit (r.diagnostics) cycles affected refusing; }) [
        (cyc [ ] badOrder)
        (cyc [ ((good 1) // { order = "late"; }) ] null)
      ];
      expected = [
        {
          cycles = [
            "t4/y3 into c.t3"
            "t3/y4 into c.t4"
          ];
          affected = [
            "c.t3"
            "c.t4"
          ];
          refusing = [
            "c.t1"
            "c.t3"
            "c.t4"
          ];
        }
        {
          cycles = [
            "t4/y3 into c.t3"
            "t3/y4 into c.t4"
          ];
          affected = [
            "c.t3"
            "c.t4"
          ];
          refusing = [
            "c.t3"
            "c.t4"
          ];
        }
      ];
    };
  };
}
