# `forward`'s refusal MESSAGES (the error plane; why a second output: `tests-error.nix`'s header).
# Every pattern is the literal text, escaped and anchored at both ends.
{ genDelivery, lib, ... }:
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
  };
}
