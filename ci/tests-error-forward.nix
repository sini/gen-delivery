# `forward`'s refusal MESSAGES (the error plane; why a second output: `tests-error.nix`'s header).
# Every pattern is the literal text, escaped and anchored at both ends.
{
  genDelivery,
  lib,
  prelude,
  ...
}:
let
  exactly = msg: "^" + lib.escapeRegex msg + "$";
  fx = import ./forward-fixture.nix { inherit genDelivery lib; };
  inherit (fx)
    route
    occ
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
  x = node: {
    class = "x";
    inherit node;
  };
  xT.x = _: null;
  pre = "gen-delivery: forward";

  base = {
    pewter.c = [
      [
        "own"
        (own "pewter")
      ]
    ];
    welt.c = [
      [
        "own"
        (own "welt")
      ]
    ];
    damask.x = [
      [
        "o1"
        (t "A")
      ]
      [
        "o2"
        (t "B")
      ]
    ];
  };
  r1 = route {
    name = "r1";
    order = [ 0 ];
    from = x "damask";
    select = occ "damask" "x" "o1";
  };
  at =
    extra:
    (run {
      cells = base;
      routes.c.pewter = [ r1 ] ++ extra;
      extraTerminals = xT;
    }).realized.c.pewter;

  cyc = run {
    cells = {
      gimp.c = [
        [
          "og"
          (own "gimp")
        ]
      ];
      lisle.c = [
        [
          "ol"
          (own "lisle")
        ]
      ];
      pewter.c = [
        [
          "own"
          (own "pewter")
        ]
      ];
    };
    routes.c = {
      lisle = [
        (route {
          name = "g2l";
          order = [ 0 ];
          from = c "gimp";
          select = "cell";
          path = [ ];
        })
      ];
      gimp = [
        (route {
          name = "l2g";
          order = [ 0 ];
          from = c "lisle";
          select = "cell";
          path = [ ];
        })
      ];
      pewter = [
        (route {
          name = "l2p";
          order = [ 0 ];
          from = c "lisle";
          select = "cell";
          path = [ ];
        })
      ];
    };
  };
  unresolvedRun =
    u:
    run {
      cells = base;
      routes.c.pewter = [ r1 ];
      unresolved = u;
      extraTerminals = xT;
    };
  # Several malformed routes in one bucket (den-hoag-in23c): every reader traverses the bucket's
  # checked memo in list order, so the first malformed route refuses, and within one route the
  # declared-key check runs before `checkRoute`. Every source carries an `s` terminal.
  good =
    i:
    route {
      name = "g${toString i}";
      order = [ i ];
      from = s "p${toString i}";
    };
  badOrder = (good 1) // {
    order = "late";
  };
  badFrom = (good 2) // {
    from = (s "nowhere") // {
      select = "declared";
    };
  };
  badKey = (good 3) // {
    colour = "red";
  };
  badKeyOrder = (good 4) // {
    colour = "red";
    order = "late";
  };
  tgt = node: {
    ${node}.c = [
      [
        "own"
        (own node)
      ]
    ];
  };
  srcs = lib.genAttrs [ "p0" "p1" "p2" "p3" "p4" ] (p: {
    s = [
      [
        "o${p}"
        (t "X${p}")
      ]
    ];
  });
  bucket =
    rs:
    run {
      cells = tgt "t0" // srcs;
      routes.c.t0 = [ (good 0) ] ++ rs;
      extraTerminals.s = _: null;
    };
  orderText = "${pre}: route into c.t0: p1/g1 must carry `order`, its declaration order, as a list of non-negative ints (the resolver supplies it)";
  # g3p6r / ovt5a: only p0 and p1 carry `s` content, and `s` has no terminal.
  srcs2 = lib.genAttrs [ "p0" "p1" ] (p: {
    s = [
      [
        "o${p}"
        (t "X${p}")
      ]
    ];
  });
  dropped = run {
    cells = tgt "t0" // tgt "t1" // srcs2;
    routes.c = {
      t0 = [ (good 0) ];
      t1 = [ ((good 1) // { from = "p1"; }) ];
    };
  };
  cycleBeside = run {
    cells = tgt "t0" // tgt "t1" // tgt "t3" // tgt "t4" // srcs;
    routes.c = {
      t0 = [ (good 0) ];
      t1 = [ badOrder ];
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
      ];
    };
    extraTerminals.s = _: null;
  };

  un = name: status: required: {
    inherit name status required;
    producer = "damask";
    site = "fixture:${name}";
    reason = "${name}-reason";
  };
in
{
  flake.testsError = {
    # ── refusals at the target, each body-placed (G7') ──
    test-forward-cycle-names-its-routes-at-the-affected-target = {
      expr = cyc.realized.c.pewter;
      expectedError.msg = exactly "${pre}: target c.pewter is affected by a forwarding cycle: lisle/l2g into c.gimp; gimp/g2l into c.lisle lie on a cycle, and the target receives what they carry";
    };
    test-forward-placement-conflict-names-the-occurrence-paths-and-routes = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o1";
          path = [
            "spools"
            "other"
          ];
        })
      ];
      expectedError.msg = exactly "${pre}: occurrence [\"damask\",\"x\",\"o1\"] arrives at target c.pewter at 2 paths (spools.pewter, spools.other; routes damask/r1, damask/r2)";
    };
    test-forward-duplicate-route-names-it-and-its-sites = {
      expr = at [
        (route {
          name = "r1";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
          site = "fixture:r1-again";
        })
      ];
      expectedError.msg = exactly "${pre}: target c.pewter: duplicate route damask/r1 (2 declarations: fixture:r1, fixture:r1-again)";
    };
    test-forward-declaration-order-tie-refuses-by-name = {
      expr = at [
        (route {
          name = "r2";
          order = [ 0 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
        })
      ];
      expectedError.msg = exactly "${pre}: target c.pewter: routes damask/r1 and damask/r2 share declaration order [0]; a structural tie is refused (fixture:r1, fixture:r2)";
    };
    test-forward-dest-segment-absent-names-the-field-and-target = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
          path = [
            "spools"
            { dest = "absent"; }
          ];
        })
      ];
      expectedError.msg = exactly "${pre}: route damask/r2: placement segment { dest = \"absent\"; }: the dest bindings have no 'absent' at target c.pewter";
    };
    test-forward-function-segment-refuses-by-name = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
          path = [ (_: "pewter") ];
        })
      ];
      expectedError.msg = exactly "${pre}: route damask/r2: placement segment is a function; a placement is structural (no function, conditional or default segment in this slice)";
    };
    test-forward-default-segment-refuses-by-name = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
          path = [
            {
              scope = "node";
              default = "pewter";
            }
          ];
        })
      ];
      expectedError.msg = exactly "${pre}: route damask/r2: placement segment [\"default\",\"scope\"] is not one of { captured | scope | dest | ref = <name>; path ? [ <name> ]; } (no conditional or default segment in this slice)";
    };
    test-forward-ambiguous-ref-segment-refuses-by-name = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o2";
          path = [
            {
              ref = "node";
              path = [ "name" ];
            }
          ];
        })
      ];
      expectedError.msg = exactly "${pre}: route damask/r2: placement segment { ref = \"node\"; } is ambiguous: both the captured and the scope bindings bind 'node'; address it explicitly";
    };
    test-forward-occurrence-not-held-names-the-source-cell = {
      expr = at [
        (route {
          name = "r2";
          order = [ 1 ];
          from = x "damask";
          select = occ "damask" "x" "o9";
        })
      ];
      expectedError.msg = exactly "${pre}: route damask/r2: selects occurrence [\"damask\",\"x\",\"o9\"], which source cell x.damask neither declares nor receives";
    };
    # D4 under an aborting group body: named, and the abort never reached.
    test-forward-duplicate-under-an-aborting-body-is-named = {
      expr =
        (run {
          cells = {
            pewter.c = [
              [
                "own"
                (own "pewter")
              ]
            ];
            damask.s = [
              [
                "o1"
                (builtins.abort "forward test: an aborting body was forced")
              ]
            ];
          };
          routes.c.pewter = [
            (route {
              name = "d";
              order = [ 0 ];
              from = s "damask";
            })
            (route {
              name = "d";
              order = [ 1 ];
              from = s "damask";
              site = "fixture:d-again";
            })
          ];
        }).realized.c.pewter;
      expectedError.msg = exactly "${pre}: target c.pewter: duplicate route damask/d (2 declarations: fixture:d, fixture:d-again)";
    };

    # ── the root doors (names only) ──
    test-forward-route-to-a-node-not-in-the-projection-refuses-by-name = {
      expr =
        (run {
          cells = base;
          routes.c.nowhere = [ r1 ];
          extraTerminals = xT;
        }).projected;
      expectedError.msg = exactly "${pre}: routes.c addresses node nowhere, which the projection does not carry — the forwarded content would be dropped";
    };
    test-forward-routes-not-class-major-refuses-by-name = {
      expr =
        (genDelivery.forward { routes.c = [ r1 ]; } fx.terminals (fx.cellsToProjected base)).projected;
      expectedError.msg = exactly "${pre}: routes.c is not an attrset — routes are CLASS-MAJOR, { <class>.<node> = [ route ]; }";
    };
    # A source cell with no instance attribution names the missing input.
    test-forward-source-without-occurrence-ids-names-the-input = {
      expr =
        let
          p = fx.cellsToProjected base;
          bare = p // {
            occurrenceIds = builtins.removeAttrs p.occurrenceIds [ "damask" ];
          };
          f = genDelivery.forward { routes.c.pewter = [ r1 ]; } (fx.terminals // xT) bare;
        in
        (genDelivery.realize { } (fx.terminals // xT) f.projected).c.pewter;
      expectedError.msg = exactly "${pre}: source cell x.damask: the projection carries no `occurrenceIds.damask.x`: occurrences are `project`'s instance attribution, and a projection without it names none";
    };
    # G15 / C2: forwarded content left in a class with no terminal refuses through realize's own
    # content check, unchanged.
    test-forward-content-left-in-a-class-with-no-terminal-refuses-through-realize = {
      expr =
        (run {
          cells = {
            pewter.c = [
              [
                "own"
                (own "pewter")
              ]
            ];
            damask.s = [
              [
                "o1"
                (t "A")
              ]
              [
                "o2"
                (t "B")
              ]
            ];
          };
          routes.c.pewter = [
            (route {
              name = "fw";
              order = [ 0 ];
              from = s "damask";
              select = occ "damask" "s" "o1";
            })
          ];
        }).realized;
      expectedError.msg = exactly "gen-delivery: realize: node damask carries declared s content, and class s has no terminal — the content would be dropped";
    };

    # ── an undeclared key on a closed resolved-form record refuses by name, with gen-prelude's shared
    # text (lrnaw). RED: `forward` ignoring the key returns a value. ──
    test-forward-route-undeclared-key-refuses-by-name = {
      expr = at [
        (
          route {
            name = "r2";
            order = [ 1 ];
            from = x "damask";
            select = occ "damask" "x" "o2";
          }
          // {
            guard = _: false;
          }
        )
      ];
      expectedError.msg = exactly (
        prelude.refusals.unknownOption "${pre}: route into c.pewter: damask/r2" [
          "from"
          "name"
          "order"
          "producer"
          "recipe"
          "required"
          "site"
        ] "guard"
      );
    };
    test-forward-unresolved-undeclared-key-refuses-by-name = {
      expr = (unresolvedRun [ ((un "n2" "N" false) // { reasn = "typo"; }) ]).check;
      expectedError.msg = exactly (
        prelude.refusals.unknownOption "${pre}: unresolved: damask/n2" [
          "name"
          "producer"
          "reason"
          "required"
          "site"
          "status"
        ] "reasn"
      );
    };

    # ── G3: the check, a separate value, names every failing route ──
    test-forward-check-names-required-n-required-e-and-optional-r = {
      expr =
        (unresolvedRun [
          (un "n1" "N" true)
          (un "e1" "E" true)
          (un "r1" "R" false)
          (un "n2" "N" false)
          (un "e2" "E" false)
        ]).check;
      expectedError.msg = exactly "${pre}: check: 3 route(s) fail: damask/n1 (required, no target: n1-reason); damask/e1 (required, excluded: e1-reason); damask/r1 (refused: r1-reason)";
    };
    test-forward-check-names-cyclic-routes = {
      expr = cyc.check;
      expectedError.msg = exactly "${pre}: check: 2 route(s) fail: lisle/l2g into c.gimp (on a forwarding cycle); gimp/g2l into c.lisle (on a forwarding cycle)";
    };
    test-forward-check-names-a-refusing-target = {
      expr =
        (run {
          cells = base;
          routes.c.pewter = [
            r1
            (route {
              name = "r2";
              order = [ 1 ];
              from = x "damask";
              select = occ "damask" "x" "o9";
            })
          ];
          extraTerminals = xT;
        }).check;
      expectedError.msg = exactly "${pre}: check: 1 route(s) fail: target c.pewter refuses its forwarded content (read the target for the reason)";
    };

    # ── several malformed routes: the first in list order refuses, the key check first within one
    # (den-hoag-in23c). RED: the memo without `checkRoute` (an evaluator error), or each bucket
    # reversed (the later route refuses). ──
    test-forward-bucket-first-malformed-route-refuses-bad-order-first = {
      expr =
        (bucket [
          badOrder
          badFrom
        ]).realized.c.t0;
      expectedError.msg = exactly orderText;
    };
    test-forward-bucket-first-malformed-route-refuses-bad-from-first = {
      expr =
        (bucket [
          badFrom
          badOrder
        ]).realized.c.t0;
      expectedError.msg = exactly "${pre}: route into c.t0: p2/g2 selects from node nowhere, which the projection does not carry";
    };
    test-forward-bucket-route-check-refuses-before-a-later-key-refusal = {
      expr =
        (bucket [
          badOrder
          badKey
        ]).realized.c.t0;
      expectedError.msg = exactly orderText;
    };
    test-forward-check-names-the-target-of-a-malformed-route = {
      expr =
        (bucket [
          badOrder
          badKey
        ]).check;
      expectedError.msg = exactly "${pre}: check: 1 route(s) fail: target c.t0 refuses its forwarded content (read the target for the reason)";
    };
    test-forward-unplaceable-route-refuses-by-its-own-text-where-its-content-is-left = {
      expr = dropped.realized.c.t0;
      expectedError.msg = exactly "${pre}: route into c.t1: p1/g1 must carry `from = { class; node; select; }`";
    };
    # den-hoag-92bpu: on a relay chain, the placement refusal a read raises is the one `received`'s settles raise
    # first (the deepest carrying hop), and between routes into one target it follows the carried occurrence keys.
    test-forward-relay-chain-placement-refuses-at-the-deepest-hop = {
      expr =
        (run {
          cells = {
            t0.c = [
              [
                "own"
                (own "t0")
              ]
            ];
            t1.c = [
              [
                "own"
                (own "t1")
              ]
            ];
            t2.c = [
              [
                "own"
                (own "t2")
              ]
            ];
            t3.c = [
              [
                "own"
                (own "t3")
              ]
            ];
            t4.c = [
              [
                "own"
                (own "t4")
              ]
            ];
            t5.c = [
              [
                "own"
                (own "t5")
              ]
            ];
          };
          routes.c = {
            t1 = [
              (route {
                name = "h0";
                order = [ 0 ];
                from = c "t0";
                select = "cell";
                path = [ "x" ];
              })
            ];
            t2 = [
              (route {
                name = "h1";
                order = [ 0 ];
                from = c "t1";
                select = "cell";
                path = [ { scope = "nope"; } ];
              })
            ];
            t3 = [
              (route {
                name = "h2";
                order = [ 0 ];
                from = c "t2";
                select = "cell";
                path = [ "x" ];
              })
            ];
            t4 = [
              (route {
                name = "h3";
                order = [ 0 ];
                from = c "t3";
                select = "cell";
                path = [ { scope = "nope"; } ];
              })
            ];
            t5 = [
              (route {
                name = "h4";
                order = [ 0 ];
                from = c "t4";
                select = "cell";
                path = [ "x" ];
              })
            ];
          };
        }).realized.c.t5;
      expectedError.msg = exactly "${pre}: route t1/h1: placement segment { scope = \"nope\"; }: the scope bindings have no 'nope'";
    };
    test-forward-placement-refusal-between-routes-follows-the-carried-keys = {
      expr =
        (run {
          cells = {
            t0.c = [
              [
                "own"
                (own "t0")
              ]
            ];
            y1.s = [
              [
                "o1"
                (t "Y1")
              ]
            ];
            y2.s = [
              [
                "o2"
                (t "Y2")
              ]
            ];
          };
          routes.c.t0 = [
            (route {
              name = "g1";
              order = [ 0 ];
              from = s "y2";
              path = [ { scope = "nope1"; } ];
            })
            (route {
              name = "g2";
              order = [ 1 ];
              from = s "y1";
              path = [ { scope = "nope2"; } ];
            })
          ];
          extraTerminals.s = _: null;
        }).realized.c.t0;
      expectedError.msg = exactly "${pre}: route y1/g2: placement segment { scope = \"nope2\"; }: the scope bindings have no 'nope2'";
    };
    test-forward-check-names-every-relay-target-a-placement-refuses = {
      expr =
        (run {
          cells = {
            t0.c = [
              [
                "own"
                (own "t0")
              ]
            ];
            t1.c = [
              [
                "own"
                (own "t1")
              ]
            ];
            t2.c = [
              [
                "own"
                (own "t2")
              ]
            ];
            t3.c = [
              [
                "own"
                (own "t3")
              ]
            ];
            t4.c = [
              [
                "own"
                (own "t4")
              ]
            ];
          };
          routes.c = {
            t1 = [
              (route {
                name = "h0";
                order = [ 0 ];
                from = c "t0";
                select = "cell";
                path = [ ];
              })
            ];
            t2 = [
              (route {
                name = "h1";
                order = [ 0 ];
                from = c "t1";
                select = "cell";
                path = [ { scope = "nope"; } ];
              })
            ];
            t3 = [
              (route {
                name = "h2";
                order = [ 0 ];
                from = c "t2";
                select = "cell";
                path = [ ];
              })
            ];
            t4 = [
              (route {
                name = "h3";
                order = [ 0 ];
                from = c "t3";
                select = "cell";
                path = [ ];
              })
            ];
          };
        }).check;
      expectedError.msg = exactly "${pre}: check: 3 route(s) fail: target c.t2 refuses its forwarded content (read the target for the reason); target c.t3 refuses its forwarded content (read the target for the reason); target c.t4 refuses its forwarded content (read the target for the reason)";
    };
    test-forward-relay-of-a-returned-occurrence-refuses-its-two-placements = {
      expr =
        (run {
          cells = {
            t0.c = [
              [
                "own"
                (own "t0")
              ]
            ];
            t1.c = [
              [
                "own"
                (own "t1")
              ]
            ];
            t2.c = [
              [
                "own"
                (own "t2")
              ]
            ];
            x.c = [
              [
                "ox"
                (own "x")
              ]
            ];
          };
          routes.c = {
            x = [
              (route {
                name = "w";
                order = [ 0 ];
                from = c "t1";
                path = [ ];
              })
            ];
            t1 = [
              (route {
                name = "back";
                order = [ 0 ];
                from = c "x";
                select = occ "t1" "c" "own";
                path = [ "a" ];
              })
            ];
            t2 = [
              (route {
                name = "h1";
                order = [ 0 ];
                from = c "t1";
                select = "cell";
                path = [ ];
              })
            ];
          };
        }).realized.c.t2;
      expectedError.msg = exactly "${pre}: occurrence [\"t1\",\"c\",\"own\"] arrives at target c.t2 at 2 paths (a, ; routes t1/h1, t1/h1)";
    };
    test-forward-check-lists-a-cycle-beside-a-malformed-route = {
      expr = cycleBeside.check;
      expectedError.msg = exactly "${pre}: check: 3 route(s) fail: t4/y3 into c.t3 (on a forwarding cycle); t3/y4 into c.t4 (on a forwarding cycle); target c.t1 refuses its forwarded content (read the target for the reason)";
    };
    test-forward-bucket-key-check-refuses-before-the-route-check = {
      expr = (bucket [ badKeyOrder ]).realized.c.t0;
      expectedError.msg = exactly (
        prelude.refusals.unknownOption "${pre}: route into c.t0: p4/g4" [
          "from"
          "name"
          "order"
          "producer"
          "recipe"
          "required"
          "site"
        ] "colour"
      );
    };
    test-forward-bucket-malformed-route-in-a-relayed-bucket-refuses-the-far-target = {
      expr =
        (run {
          cells = tgt "t0" // tgt "t1" // tgt "t2" // srcs;
          routes.c = {
            t1 = [
              (route {
                name = "h0";
                order = [ 0 ];
                from = c "t0";
                select = "cell";
                path = [ ];
              })
              badOrder
            ];
            t2 = [
              (route {
                name = "h1";
                order = [ 0 ];
                from = c "t1";
                select = "cell";
                path = [ ];
              })
            ];
          };
          extraTerminals.s = _: null;
        }).realized.c.t2;
      expectedError.msg = exactly "${pre}: route into c.t1: p1/g1 must carry `order`, its declaration order, as a list of non-negative ints (the resolver supplies it)";
    };
  };
}
