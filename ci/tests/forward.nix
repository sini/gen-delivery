# `forward` — the first forwarding slice (M1 imports-at-path, occurrence relays, the explicit
# whole-cell adapter), through the REAL `forward` and the REAL `realize`, against nixpkgs' module
# system as the receiver (`../forward-fixture.nix`). The refusal MESSAGES are held on the error
# plane (`../tests-error-forward.nix`); these cells hold values, THAT a read refuses, and laziness.
#
# Reading the bytes: one emitted module at `spools.pewter` holding groups in the delivered order
# o1 … ok merges, with the receiver's own `R`, to "ok\n…\no1\nR" (nixpkgs' `lines` merge of one
# module's imports), so a value names the delivered order exactly. Measured on this receiver before
# the cells were written: one group [ A B ] reads "B\nA\nR", per-item wrapping "A\nB\nR". At the
# ROOT (`importsAt [ ]`) the arrangement differs and so do the bytes: one root item Y beside the
# receiver's own R reads "R\nY". Between modules at DIFFERENT paths the native merge order is
# structural: two overlapping paths read one value in either module order (P3 below).
{ genDelivery, lib, ... }:
let
  fx = import ../forward-fixture.nix { inherit genDelivery lib; };
  inherit (fx)
    route
    occ
    run
    own
    mA
    mA'
    mB
    t
    ok
    ;
  s = node: {
    class = "s";
    inherit node;
  };
  c = node: {
    class = "c";
    inherit node;
  };
  # A source class WITH a terminal that discards its modules: no C2 stripping, nothing forced.
  x = node: {
    class = "x";
    inherit node;
  };
  xT.x = _: null;
  thread = r: n: r.realized.c.${n}.${n}.thread;

  # ── G12 / one occurrence: damask's group [ mA mB ] into pewter ──
  oneOcc = run {
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
          mA
        ]
        [
          "o1"
          mB
        ]
      ];
    };
    routes.c.pewter = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
  };
  # ── G12 two occurrences / G16 / G17 ──
  twoOcc =
    {
      second ? [
        "o2"
        mB
      ],
      path2 ? null,
    }:
    run {
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
            mA
          ]
          second
        ];
      };
      routes.c.pewter =
        if path2 == null then
          [
            (route {
              name = "fw";
              order = [ 0 ];
              from = s "damask";
            })
          ]
        else
          [
            (route {
              name = "f1";
              order = [ 0 ];
              from = s "damask";
              select = occ "damask" "s" "o1";
            })
            (route {
              name = "f2";
              order = [ 1 ];
              from = s "damask";
              select = occ "damask" "s" (builtins.head second);
              path = path2;
            })
          ];
    };
  twoPaths = twoOcc {
    path2 = [
      "spools"
      "damask"
    ];
  };

  # ── ORDER (F1, C3): received-then-declared, routes by declaration order, never by name/list ──
  # Two producers, damask (A) and faille (B), each forwarding one occurrence into pewter; the
  # declared order decides, whatever the names and the list order.
  twoProducers =
    {
      orderA,
      orderB,
      listAFirst ? true,
    }:
    let
      ra = route {
        name = "zz";
        order = orderA;
        from = s "damask";
      };
      rb = route {
        name = "aa";
        order = orderB;
        from = s "faille";
      };
    in
    run {
      cells = {
        pewter.c = [
          [
            "own"
            (own "pewter")
          ]
        ];
        damask.s = [
          [
            "oa"
            (t "A")
          ]
        ];
        faille.s = [
          [
            "ob"
            (t "B")
          ]
        ];
      };
      routes.c.pewter =
        if listAFirst then
          [
            ra
            rb
          ]
        else
          [
            rb
            ra
          ];
    };
  # A W1 relay: faille's cell receives damask's occurrence and declares its own; the whole cell goes
  # to pewter: received first, then declared.
  relayW1 =
    select:
    run {
      cells = {
        pewter.c = [
          [
            "own"
            (own "pewter")
          ]
        ];
        damask.x = [
          [
            "oa"
            (t "A")
          ]
        ];
        faille.x = [
          [
            "ob"
            (t "B")
          ]
        ];
      };
      routes = {
        x.faille = [
          (route {
            name = "in";
            order = [ 0 ];
            from = x "damask";
            path = [ ];
          })
        ];
        c.pewter = [
          (route {
            name = "w";
            order = [ 0 ];
            from = x "faille";
            inherit select;
          })
        ];
      };
      extraTerminals = xT;
    };

  # A W1 adapter embeds the cell as realized there: faille's x cell receives damask's A at
  # `spools.pewter`, and the whole cell goes to pewter at its root, so A lands at spools.pewter.
  w1Placement = run {
    cells = {
      pewter.c = [
        [
          "own"
          (own "pewter")
        ]
      ];
      faille.x = [ ];
      damask.x = [
        [
          "oa"
          (t "A")
        ]
      ];
    };
    routes = {
      x.faille = [
        (route {
          name = "in";
          order = [ 0 ];
          from = x "damask";
          path = [
            "spools"
            "pewter"
          ];
        })
      ];
      c.pewter = [
        (route {
          name = "w";
          order = [ 0 ];
          from = x "faille";
          select = "cell";
          path = [ ];
        })
      ];
    };
    extraTerminals = xT;
  };

  # ── (a″): one function-form module per ROUTE at its inner path ──
  # A two-level receiver `f`: frame (submodule) > spools (attrsOf) > thread (lines). Items reach the
  # mid cell x.tux at spools.pewter; tux's whole x cell reaches f.pewter at `frame` (W1). Measured
  # hand-built on this receiver before the cells were written: one module at spools.pewter holding
  # [ A B ] reads "B\nA\nR"; two modules [ A ], [ B ] read "A\nB\nR".
  frameRecv = {
    options.frame = lib.mkOption {
      type = lib.types.submoduleWith {
        shorthandOnlyDefinesConfig = true;
        modules = [
          {
            options.spools = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submoduleWith {
                  shorthandOnlyDefinesConfig = true;
                  modules = [
                    {
                      options.thread = lib.mkOption {
                        type = lib.types.lines;
                        default = "";
                      };
                    }
                  ];
                }
              );
              default = { };
            };
          }
        ];
      };
      default = { };
    };
  };
  frameT = xT // {
    f =
      { modules, ... }:
      (lib.evalModules { modules = [ frameRecv ] ++ modules; }).config.frame.spools.pewter.thread;
  };
  pp = [
    "spools"
    "pewter"
  ];
  nested =
    { cell, items }:
    run {
      cells = {
        pewter.f = [
          [
            "own"
            { frame.spools.pewter.thread = "R"; }
          ]
        ];
        tux.x = [ ];
        damask.x = cell;
        faille.x = [
          [
            "ob2"
            (t "B")
          ]
        ];
      };
      routes = {
        x.tux = items;
        f.pewter = [
          (route {
            name = "embed";
            order = [ 0 ];
            from = x "tux";
            select = "cell";
            path = [ "frame" ];
          })
        ];
      };
      extraTerminals = frameT;
    };
  item2 =
    cellOrder:
    nested {
      cell = map (id: [
        id
        (t (if id == "oa" then "A" else "B"))
      ]) cellOrder;
      items = [
        (route {
          name = "both";
          order = [ 0 ];
          from = x "damask";
          path = pp;
        })
      ];
    };
  twoItems = nested {
    cell = [
      [
        "oa"
        (t "A")
      ]
    ];
    items = [
      (route {
        name = "ra";
        order = [ 0 ];
        from = x "damask";
        path = pp;
      })
      (route {
        name = "rb";
        order = [ 1 ];
        from = x "faille";
        path = pp;
      })
    ];
  };
  fThread = r: r.realized.f.pewter;

  # ── G5r / K2 / K3: the relay cells (class k, a discarding terminal; read at Z's wrapper) ──
  # X declares ox, P declares op; P ⇄ Q exchange whole cells (a genuine cycle carrying op). W is an
  # unrelated sibling whose bucket holds a route that throws when forced (the forcing-safe negative
  # control); V is an unrelated sibling with a valid route (the sibling-positive control).
  relayCells = {
    X = [
      [
        "ox"
        { t = "ox"; }
      ]
    ];
    P = [
      [
        "op"
        { t = "op"; }
      ]
    ];
    Q = [ ];
    Y = [ ];
    Z = [ ];
    W = [ ];
    V = [ ];
    S = [
      [
        "os"
        { t = "os"; }
      ]
    ];
  };
  rk =
    name: order: node: select:
    route {
      inherit name order select;
      from = {
        class = "k";
        inherit node;
      };
      path = [ ];
    };
  relayK = id: node: rk "z" [ 0 ] "Y" (occ node "k" id);
  relayRunWith =
    sentinel: ks:
    run {
      cells = builtins.mapAttrs (_: cs: { k = cs; }) relayCells;
      routes.k =
        ks
        // {
          V = [ (rk "v" [ 0 ] "S" "declared") ];
        }
        // (
          if sentinel then
            { W = [ (throw "forward test: an unrelated sibling's route was forced") ]; }
          else
            { }
        );
      extraTerminals.k = _: null;
    };
  relayRun = relayRunWith true;
  wrapAt =
    r: n:
    builtins.elemAt r.projected.nodes.${n}.classes.k (
      builtins.length r.projected.nodes.${n}.classes.k - 1
    );
  readZ = r: map (m: m.t) (wrapAt r "Z" { }).imports;
  tryZ =
    r:
    let
      v = builtins.tryEval (builtins.deepSeq (readZ r) (readZ r));
    in
    if v.success then v.value else "REFUSED";
  base = {
    Q = [ (rk "pq" [ 0 ] "P" "cell") ];
    Y = [
      (rk "xy" [ 0 ] "X" "cell")
      (rk "py" [ 1 ] "P" "cell")
    ];
  };
  relayRoutes = {
    relay-ox = (
      base
      // {
        P = [ (rk "qp" [ 0 ] "Q" "cell") ];
        Z = [ (relayK "ox" "X") ];
      }
    );
    relay-op = (
      base
      // {
        P = [ (rk "qp" [ 0 ] "Q" "cell") ];
        Z = [ (relayK "op" "P") ];
      }
    );
    relay-ox-nocycle = (base // { Z = [ (relayK "ox" "X") ]; });
    relay2-ox = {
      Q = [ (rk "pq" [ 0 ] "P" "cell") ];
      P = [ (rk "qp" [ 0 ] "Q" "cell") ];
      X = [ (rk "px" [ 0 ] "P" "cell") ];
      Y = [ (rk "xy" [ 0 ] "X" "cell") ];
      Z = [ (relayK "ox" "X") ];
    };
    relay2-op = {
      Q = [ (rk "pq" [ 0 ] "P" "cell") ];
      P = [ (rk "qp" [ 0 ] "Q" "cell") ];
      X = [ (rk "px" [ 0 ] "P" "cell") ];
      Y = [ (rk "xy" [ 0 ] "X" "cell") ];
      Z = [ (relayK "op" "P") ];
    };
    relay3-ox = {
      Y = [ (rk "xy" [ 0 ] "X" "cell") ];
      X = [ (rk "yx" [ 0 ] "Y" "cell") ];
      Z = [ (relayK "ox" "X") ];
    };
    relay4-op = {
      Q = [ (rk "pq" [ 0 ] "P" "cell") ];
      P = [ (rk "qp" [ 0 ] "Q" "cell") ];
      Z = [ (rk "z" [ 0 ] "P" (occ "P" "k" "op")) ];
    };
  };
  relays = builtins.mapAttrs (_: relayRun) relayRoutes;
  relaysNoSentinel = builtins.mapAttrs (_: relayRunWith false) relayRoutes;

  # ── G4 / G5: cycles, legal two-way exchange, taint ──
  # gimp ⇄ lisle, both W1, both with a terminal: a genuine cycle. pewter receives W1 from lisle (one
  # hop), damask W1 from pewter (two hops); faille relays gimp's declared occurrence from lisle (an
  # occurrence relay of a tainted occurrence); bouclé relays it on from faille (two hops); moire
  # takes lisle's OWN declared occurrence by an item route: the cycle carries it (l2g), so it is
  # tainted, and the walk does not stop at its declaring cell (K3, the relay4-op shape). velour
  # takes pewter's own declared occurrence: pewter RECEIVES tainted content and that occurrence is
  # carried by no cyclic route (co-location: never tainted).
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
      damask.c = [
        [
          "own"
          (own "damask")
        ]
      ];
      faille.c = [
        [
          "own"
          (own "faille")
        ]
      ];
      boucle.c = [
        [
          "own"
          (own "boucle")
        ]
      ];
      moire.c = [
        [
          "own"
          (own "moire")
        ]
      ];
      velour.c = [
        [
          "own"
          (own "velour")
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
      damask = [
        (route {
          name = "p2d";
          order = [ 0 ];
          from = c "pewter";
          select = "cell";
          path = [ ];
        })
      ];
      faille = [
        (route {
          name = "rel1";
          order = [ 0 ];
          from = c "lisle";
          select = occ "gimp" "c" "og";
          path = [ ];
        })
      ];
      boucle = [
        (route {
          name = "rel2";
          order = [ 0 ];
          from = c "faille";
          select = occ "gimp" "c" "og";
          path = [ ];
        })
      ];
      moire = [
        (route {
          name = "item";
          order = [ 0 ];
          from = c "lisle";
          select = occ "lisle" "c" "ol";
          path = [ ];
        })
      ];
      velour = [
        (route {
          name = "coloc";
          order = [ 0 ];
          from = c "pewter";
          select = occ "pewter" "c" "own";
          path = [ ];
        })
      ];
    };
  };
  # Legal two-way exchange: item X gimp → lisle and item Y lisle → gimp, independent declared items.
  exchange = run {
    cells = {
      gimp.c = [
        [
          "own"
          (own "gimp")
        ]
        [
          "x"
          { spools.lisle.thread = "X"; }
        ]
      ];
      lisle.c = [
        [
          "own"
          (own "lisle")
        ]
        [
          "y"
          { spools.gimp.thread = "Y"; }
        ]
      ];
    };
    routes.c = {
      lisle = [
        (route {
          name = "x";
          order = [ 0 ];
          from = c "gimp";
          select = occ "gimp" "c" "x";
          path = [ ];
        })
      ];
      gimp = [
        (route {
          name = "y";
          order = [ 0 ];
          from = c "lisle";
          select = occ "lisle" "c" "y";
          path = [ ];
        })
      ];
    };
  };

  # ── G6: occurrence-once ──
  # A diamond: damask's o1 reaches pewter through two terminal-less relays, faille and gimp (one L,
  # two routes): one copy. An overlap: an item route plus a W1 of the same cell: one copy.
  diamond = run {
    cells = {
      pewter.c = [
        [
          "own"
          (own "pewter")
        ]
      ];
      faille.c = [
        [
          "own"
          (own "faille")
        ]
      ];
      gimp.c = [
        [
          "own"
          (own "gimp")
        ]
      ];
      damask.s = [
        [
          "o1"
          (t "A")
        ]
      ];
    };
    routes = {
      x.faille = [
        (route {
          name = "a";
          order = [ 0 ];
          from = s "damask";
          path = [ ];
        })
      ];
      x.gimp = [
        (route {
          name = "b";
          order = [ 0 ];
          from = s "damask";
          path = [ ];
        })
      ];
      c.pewter = [
        (route {
          name = "fa";
          order = [ 0 ];
          from = {
            class = "x";
            node = "faille";
          };
          select = "cell";
        })
        (route {
          name = "gi";
          order = [ 1 ];
          from = {
            class = "x";
            node = "gimp";
          };
          select = "cell";
        })
      ];
    };
  };
  overlap = run {
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
        name = "item";
        order = [ 0 ];
        from = s "damask";
        select = occ "damask" "s" "o1";
      })
      (route {
        name = "whole";
        order = [ 1 ];
        from = s "damask";
        select = "cell";
      })
    ];
  };

  # ── G7 / G7': integrated refusal, siblings, the three grouping-time faults ──
  sentinel = throw "forward test: sentinel forced";
  faulted =
    fault:
    let
      base = [
        (route {
          name = "r1";
          order = [ 0 ];
          from = x "damask";
          select = occ "damask" "x" "o1";
        })
      ];
      extra = {
        none = [ ];
        conflict = [
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
        dupname = [
          (route {
            name = "r1";
            order = [ 1 ];
            from = x "damask";
            select = occ "damask" "x" "o2";
            site = "fixture:r1-again";
          })
        ];
        paththrow = [
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
        tie = [
          (route {
            name = "r2";
            order = [ 0 ];
            from = x "damask";
            select = occ "damask" "x" "o2";
          })
        ];
      };
    in
    run {
      cells = {
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
            mA
          ]
          [
            "o2"
            mB
          ]
        ];
      };
      routes.c.pewter = base ++ extra.${fault};
      extraTerminals = xT;
    };
  # An affected target (the gimp ⇄ lisle cycle) beside an unrelated same-class sibling whose
  # content holds a sentinel it never forces, and a peer reading the affected through `extent`.
  integrated = run {
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
      welt.c = [
        [
          "own"
          (own "welt")
        ]
        [
          "s"
          { spools.unread.thread = sentinel; }
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
    };
    # welt's artifact carries a lazy read of gimp's through `extent`, the class's own peer accessor.
    extraTerminals.c =
      {
        modules,
        extent,
        name,
        ...
      }:
      fx.spoolsOf modules // (if name == "welt" then { peerRead = extent.gimp; } else { });
  };

  # ── G8: identity distinctions ──
  # A path module imported natively by two distinct occurrences: native dedup keeps one definition.
  pathImport = run {
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
          ../forward-path-module.nix
        ]
        [
          "o2"
          ../forward-path-module.nix
        ]
      ];
    };
    routes.c.pewter = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
  };
  renamed =
    nm:
    run {
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
        ];
      };
      routes.c.pewter = [
        (route {
          name = nm;
          order = [ 0 ];
          from = s "damask";
          select = occ "damask" "s" "o1";
        })
        (route {
          name = "${nm}-twin";
          order = [ 1 ];
          from = s "damask";
          select = occ "damask" "s" "o1";
        })
      ];
    };

  # ── G9 (P5): one local name from two producers is two routes ──
  twoProducersSameName = run {
    cells = {
      pewter.c = [
        [
          "own"
          (own "pewter")
        ]
      ];
      damask.s = [
        [
          "oa"
          (t "A")
        ]
      ];
      faille.s = [
        [
          "ob"
          (t "B")
        ]
      ];
    };
    routes.c.pewter = [
      (route {
        name = "same";
        order = [ 0 ];
        from = s "damask";
      })
      (route {
        name = "same";
        order = [ 1 ];
        from = s "faille";
      })
    ];
  };
  # A duplicate route name whose group ABORTS when forced: the refusal is named and catchable.
  dupAbort = run {
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
  };

  # ── G10: laziness ──
  # An unrelated target's bucket holds a route whose every field throws; a discarded (unselected)
  # occurrence and a binding no segment reads throw too. None is forced by pewter's read.
  lazy = run {
    cells = {
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
          sentinel
        ]
      ];
    };
    routes.c = {
      pewter = [
        (route {
          name = "fw";
          order = [ 0 ];
          from = x "damask";
          select = occ "damask" "x" "o1";
        })
      ];
      welt = [ sentinel ];
    };
    extraTerminals = xT;
  };

  # ── G11: no claim over opaque captured evaluation dependencies ──
  opaque = run {
    cells = {
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
      damask.s = [
        [
          "o1"
          (t "A")
        ]
      ];
    };
    routes.c.pewter = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
    # Each target's artifact carries a lazy read of the other's through `extent`: a cycle no route
    # carries.
    extraTerminals.c =
      {
        modules,
        extent,
        name,
        ...
      }:
      fx.spoolsOf modules // { peer = extent.${if name == "pewter" then "welt" else "pewter"}; };
  };

  # ── G13: the placement grammar ──
  grammar =
    seg:
    run {
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
        ];
      };
      routes.c.pewter = [
        (route {
          name = "fw";
          order = [ 0 ];
          from = s "damask";
          path = [
            "spools"
            seg
          ];
        })
      ];
    };

  # ── G15: an address the realization does not hold ──
  noTerminal = run {
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
      ];
    };
    routes.z.pewter = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
  };
  noNode = run {
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
      ];
    };
    routes.c.nowhere = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
  };

  # ── C2: consumed vs dropped content of a cell with no terminal ──
  partial = run {
    cells = {
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
  };
  # damask's s cell receives faille's occurrence and is consumed whole by a W1 route to pewter.
  w1Consumed = run {
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
      ];
      faille.s = [
        [
          "ob"
          (t "B")
        ]
      ];
    };
    routes = {
      s.damask = [
        (route {
          name = "in";
          order = [ 0 ];
          from = s "faille";
          path = [ ];
        })
      ];
      c.pewter = [
        (route {
          name = "w";
          order = [ 0 ];
          from = s "damask";
          select = "cell";
        })
      ];
    };
  };

  # ── P3: overlapping paths, declared order and swapped ──
  overlapping =
    swapped:
    run {
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
        ];
        faille.s = [
          [
            "o2"
            { spools.pewter.thread = "B"; }
          ]
        ];
      };
      # `spools.pewter` and the root `[ ]`, the root a prefix of the other: both reach
      # spools.pewter.thread.
      routes.c.pewter = [
        (route {
          name = "deep";
          order = if swapped then [ 1 ] else [ 0 ];
          from = s "damask";
        })
        (route {
          name = "shallow";
          order = if swapped then [ 0 ] else [ 1 ];
          from = s "faille";
          path = [ ];
        })
      ];
    };

  # ── G3 ──
  unresolvedOver =
    u:
    run {
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
        ];
      };
      routes.c.pewter = [
        (route {
          name = "fw";
          order = [ 0 ];
          from = s "damask";
        })
      ];
      unresolved = u;
    };
  un = name: status: required: {
    inherit name status required;
    producer = "damask";
    site = "fixture:${name}";
    reason = "${name}-reason";
  };
  optionalOnly = unresolvedOver [
    (un "n2" "N" false)
    (un "e2" "E" false)
  ];
  failingCheck = unresolvedOver [
    (un "n1" "N" true)
    (un "r1" "R" false)
  ];

  # ── G2: string context reaches the consumer ──
  src = derivation {
    name = "forward-test-source";
    system = "x86_64-linux";
    builder = "/bin/sh";
  };
  ctx = run {
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
          (t "${src}")
        ]
      ];
    };
    routes.c.pewter = [
      (route {
        name = "fw";
        order = [ 0 ];
        from = s "damask";
      })
    ];
  };
in
{
  flake.tests.forward = {
    # ── G12: the nested receiver ──
    # RED: per-item wrapping reads "A\nB\nR"; a swapped group "A\nB\nR"; a twice-delivered group
    # "B\nA\nB\nA\nR"; `forward` absent: no attribute `forward`.
    test-g12-one-occurrence-group-placed-as-a-group = {
      expr = oneOcc.realized.c.pewter.pewter;
      expected = {
        thread = "B\nA\nR";
        spindle = "receiver";
      };
    };
    # RED: one module per occurrence in declaration order reads "A\nB\nR".
    test-g12-two-occurrences-one-module-per-path = {
      expr = thread (twoOcc { }) "pewter";
      expected = "B\nA\nR";
    };
    # G16. RED: a value-dedup mutant keeps one, "A\nR".
    test-g16-equal-content-distinct-occurrences-stay-two = {
      expr = thread (twoOcc {
        second = [
          "o3"
          mA'
        ];
      }) "pewter";
      expected = "A\nA\nR";
    };
    # G17. RED: a mutant merging both paths into pewter's module reads pewter "B\nA\nR", damask absent.
    test-g17-different-paths-stay-separate = {
      expr = {
        pewter = twoPaths.realized.c.pewter.pewter.thread;
        damask = twoPaths.realized.c.pewter.damask.thread;
      };
      expected = {
        pewter = "A\nR";
        damask = "B";
      };
    };

    # ── order (F1 / C3) ──
    # The declared order decides; route names (`zz` before `aa`) and the bucket's list order are
    # not read. RED: name order reads "A\nB\nR" for the first arm; list order flips with the list.
    test-order-declared-a-first = {
      expr = thread (twoProducers {
        orderA = [ 0 ];
        orderB = [ 1 ];
      }) "pewter";
      expected = "B\nA\nR";
    };
    test-order-declared-b-first = {
      expr = thread (twoProducers {
        orderA = [ 1 ];
        orderB = [ 0 ];
      }) "pewter";
      expected = "A\nB\nR";
    };
    test-order-list-order-not-read = {
      expr = thread (twoProducers {
        orderA = [ 0 ];
        orderB = [ 1 ];
        listAFirst = false;
      }) "pewter";
      expected = "B\nA\nR";
    };
    # A multi-int declaration order is compared lexicographically: the first differing position
    # decides, and a proper prefix sorts first. A first reads "B\nA\nR", B first "A\nB\nR". Each arm
    # lists the route that must come SECOND first, so a comparator that cannot tell the two apart
    # (stable sort) reads the opposite. RED: comparing the first int only flips every arm; a
    # reversed length rule (a prefix sorts last) flips `length` and `length-swapped`.
    test-order-multi-int-declaration-order-is-lexicographic = {
      expr =
        builtins.mapAttrs
          (
            _: a:
            thread (twoProducers {
              inherit (a) orderA orderB;
              listAFirst = a.aFirstInList;
            }) "pewter"
          )
          {
            # [ 0 0 5 ] < [ 0 1 ] at position 1, the longer one first: B first.
            first-difference = {
              orderA = [
                0
                1
              ];
              orderB = [
                0
                0
                5
              ];
              aFirstInList = true;
            };
            # [ 0 ] is a proper prefix of [ 0 0 ]: B first.
            length = {
              orderA = [
                0
                0
              ];
              orderB = [ 0 ];
              aFirstInList = true;
            };
            # The same pair swapped: A, the prefix, first.
            length-swapped = {
              orderA = [ 0 ];
              orderB = [
                0
                0
              ];
              aFirstInList = false;
            };
            # [ 0 1 9 ] < [ 0 2 ] at position 1, the longer one first: B first.
            later-position = {
              orderA = [
                0
                2
              ];
              orderB = [
                0
                1
                9
              ];
              aFirstInList = true;
            };
          };
      expected = {
        first-difference = "A\nB\nR";
        length = "A\nB\nR";
        length-swapped = "B\nA\nR";
        later-position = "A\nB\nR";
      };
    };
    # Received-then-declared through a W1 cell: damask's A (received at faille) before faille's B.
    test-order-received-before-declared-through-w1 = {
      expr = thread (relayW1 "cell") "pewter";
      expected = "B\nA\nR";
    };

    # RED (the received placement dropped at the W1 hop): A lands at the receiver's root, which
    # declares no `thread`, and pewter's read throws.
    test-w1-carries-the-received-placement-below-its-own = {
      expr = thread w1Placement "pewter";
      expected = "A\nR";
    };

    # ── (a″) ──
    # One route carrying two occurrences: ONE module at its inner path holding them in the cell's
    # order, both include orders. RED: the per-occurrence (a′) emission reads the other value.
    test-a2-one-route-two-occurrences-one-module-cell-order = {
      expr = map (o: fThread (item2 o)) [
        [
          "oa"
          "ob"
        ]
        [
          "ob"
          "oa"
        ]
      ];
      expected = [
        "B\nA\nR"
        "A\nB\nR"
      ];
    };
    # Two routes, one occurrence each: one module per route, in declaration order. RED: arm (a) at
    # every hop groups them into one module, "B\nA\nR".
    test-a2-two-routes-two-modules-declaration-order = {
      expr = fThread twoItems;
      expected = "A\nB\nR";
    };

    # ── G5r / K2 / K3: relays out of a cell that receives tainted content ──
    # Untainted ox relayed out of a cell whose W1 inflow also carries the cyclic op: delivered.
    # RED (build v0 F3, the head before K2): refused. RED (`lit`, the key scope in the analysis
    # only): an uncatchable stack overflow, a suite abort.
    test-g5r-untainted-key-relayed-out-of-a-tainted-cell-is-delivered = {
      expr = map (c: tryZ relays.${c}) [
        "relay-ox"
        "relay-ox-nocycle"
        "relay2-ox"
      ];
      expected = [
        [ "ox" ]
        [ "ox" ]
        [ "ox" ]
      ];
    };
    # The tainted key refuses: relayed through a tainted cell, out of its declaring cell (K3,
    # relay4-op), and carried by a route that is itself cyclic (relay3-ox). RED (K3: the walk stops
    # at a declaring cell): relay4-op delivers [ "op" ].
    test-g5r-tainted-key-relays-refuse = {
      expr = map (c: tryZ relays.${c}) [
        "relay-op"
        "relay2-op"
        "relay3-ox"
        "relay4-op"
      ];
      expected = [
        "REFUSED"
        "REFUSED"
        "REFUSED"
        "REFUSED"
      ];
    };
    # Forcing-safe negative control: no relay read forces the unrelated sibling W's route, and the
    # sibling-positive control: V's valid route delivers beside every refusing Z.
    test-g5r-unrelated-siblings-unforced-and-usable = {
      expr = builtins.mapAttrs (_: r: map (m: m.t) (wrapAt r "V" { }).imports) relays;
      expected = builtins.mapAttrs (_: _: [ "os" ]) relays;
    };
    test-g5r-refusals-name-the-cycle = {
      expr = builtins.mapAttrs (_: r: builtins.elem "k.Z" r.diagnostics.affected) relaysNoSentinel;
      expected = {
        relay-ox = false;
        relay-ox-nocycle = false;
        relay2-ox = false;
        relay-op = true;
        relay2-op = true;
        relay3-ox = true;
        relay4-op = true;
      };
    };

    # ── G14: W1 vs W2 ──
    # RED: a W2 reading of "cell" drops the received A, "B\nR".
    test-g14-w2-carries-declared-only = {
      expr = thread (relayW1 "declared") "pewter";
      expected = "B\nR";
    };

    # ── G4: a genuine cycle refuses; legal two-way exchange delivers both ──
    test-g4-cycle-refuses-at-its-targets = {
      expr = {
        gimp = ok cyc.realized.c.gimp;
        lisle = ok cyc.realized.c.lisle;
      };
      expected = {
        gimp = false;
        lisle = false;
      };
    };
    # RED: a cell-graph mutant (an edge per route pair) refuses the exchange.
    test-g4-legal-two-way-exchange-delivers-both = {
      expr = {
        gimp = exchange.realized.c.gimp.gimp.thread;
        lisle = exchange.realized.c.lisle.lisle.thread;
        cycles = exchange.diagnostics.cycles;
      };
      expected = {
        gimp = "R\nY";
        lisle = "R\nX";
        cycles = [ ];
      };
    };

    # ── G5: transitive taint, W1 and occurrence relays; co-location never taints ──
    # RED: an omitted-relay mutant delivers at boucle / damask; a co-location mutant refuses velour;
    # the stop-at-a-declaring-cell head (K3) delivers moire.
    test-g5-taint-reaches-every-relay-target = {
      expr = builtins.mapAttrs (n: _: ok cyc.realized.c.${n}) {
        pewter = 1;
        damask = 2;
        faille = 1;
        boucle = 2;
      };
      expected = {
        pewter = false;
        damask = false;
        faille = false;
        boucle = false;
      };
    };
    test-g5-co-located-independent-item-is-delivered = {
      expr = cyc.realized.c.velour.velour.thread;
      expected = "R";
    };
    test-g5-co-located-item-is-not-affected = {
      expr = builtins.elem "c.velour" cyc.diagnostics.affected;
      expected = false;
    };
    # K3: an item route out of the cell that declares it, while a cycle carries that occurrence.
    test-k3-item-out-of-its-declaring-cell-on-a-cycle-refuses = {
      expr = {
        moire = ok cyc.realized.c.moire;
        affected = builtins.elem "c.moire" cyc.diagnostics.affected;
      };
      expected = {
        moire = false;
        affected = true;
      };
    };
    test-g4-diagnostics-name-the-cycle = {
      expr = cyc.diagnostics.cycles;
      expected = [
        "lisle/l2g into c.gimp"
        "gimp/g2l into c.lisle"
      ];
    };

    # ── G6: occurrence-once ──
    # RED: a `twice` mutant reads "A\nA\nR" for the diamond and "B\nA\nA\nR" for the overlap.
    test-g6-diamond-delivers-one-copy = {
      expr = thread diamond "pewter";
      expected = "A\nR";
    };
    test-g6-overlap-delivers-one-copy-in-first-declared-position = {
      expr = thread overlap "pewter";
      expected = "B\nA\nR";
    };

    # ── G7: the affected target refuses; the sibling and the key set stay usable ──
    # RED: a post-`realize` guard leaves the peer's `extent` read delivering pewter's value.
    test-g7-affected-target-refuses = {
      expr = ok integrated.realized.c.gimp;
      expected = false;
    };
    test-g7-unrelated-sibling-is-usable-and-its-sentinel-unforced = {
      expr = integrated.realized.c.welt.welt;
      expected = {
        thread = "R";
        spindle = "receiver";
      };
    };
    test-g7-class-key-set-is-usable = {
      expr = builtins.attrNames integrated.realized.c;
      expected = [
        "gimp"
        "lisle"
        "welt"
      ];
    };
    test-g7-peer-reading-the-affected-through-extent-inherits-the-refusal = {
      expr = ok integrated.realized.c.welt.peerRead;
      expected = false;
    };

    # ── G7': each grouping-time fault is body-placed (gate C1) ──
    # RED: the top-level per-path emission (one list element per path): the sibling's read and the
    # key set throw under every fault.
    test-g7p-faults-leave-the-sibling-usable = {
      expr = map (f: (faulted f).realized.c.welt.welt.thread) [
        "conflict"
        "dupname"
        "paththrow"
        "tie"
      ];
      expected = [
        "R"
        "R"
        "R"
        "R"
      ];
    };
    test-g7p-faults-leave-the-key-set-usable = {
      expr = map (f: builtins.attrNames (faulted f).realized.c) [
        "conflict"
        "dupname"
        "paththrow"
        "tie"
      ];
      expected = builtins.genList (_: [
        "pewter"
        "welt"
      ]) 4;
    };
    test-g7p-faults-refuse-at-the-target = {
      expr = map (f: ok (faulted f).realized.c.pewter) [
        "none"
        "conflict"
        "dupname"
        "paththrow"
        "tie"
      ];
      expected = [
        true
        false
        false
        false
        false
      ];
    };

    # ── G8: identity distinctions ──
    # Two routes, one L: one delivery, under either route name (R changes, L and D do not). RED: a
    # mutant keying D by route delivers twice, "A\nA\nR".
    test-g8-two-routes-one-occurrence-one-delivery = {
      expr = map (nm: thread (renamed nm) "pewter") [
        "spool"
        "bobbin"
      ];
      expected = [
        "A\nR"
        "A\nR"
      ];
    };
    # Two distinct occurrences importing one path: native dedup keeps one definition; `forward`
    # adds no `key`. RED: a mutant adding a per-delivery key reads "P\nP\nR".
    test-g8-native-path-dedup-is-kept = {
      expr = thread pathImport "pewter";
      expected = "P\nR";
    };

    # ── G9 (D4, P5) ──
    test-g9-same-name-two-producers-is-two-routes = {
      expr = thread twoProducersSameName "pewter";
      expected = "B\nA\nR";
    };
    # The duplicate refuses catchably though the group aborts when forced: the refusal reads names
    # and sites only. RED: a refusal that renders the group aborts past `tryEval`.
    test-g9-duplicate-under-an-aborting-body-is-catchable = {
      expr = (builtins.tryEval (builtins.deepSeq dupAbort.realized.c.pewter null)).success;
      expected = false;
    };

    # ── G10: laziness ──
    # RED: an eager-validation mutant (every bucket checked on any read) throws the sentinel.
    test-g10-unrelated-bucket-discarded-occurrence-and-bindings-unforced = {
      expr = lazy.realized.c.pewter.pewter.thread;
      expected = "A\nR";
    };
    test-g10-transformed-projection-key-set-reads-no-route-body = {
      expr = builtins.attrNames lazy.projected.nodes;
      expected = [
        "damask"
        "pewter"
        "welt"
      ];
    };

    # ── G11: opaque dependencies are not routes ──
    test-g11-no-route-cycle-is-claimed-for-opaque-reads = {
      expr = opaque.diagnostics.cycles;
      expected = [ ];
    };

    # ── G13: the grammar ──
    test-g13-dest-segment-resolves-from-destination-metadata = {
      expr = thread (grammar { dest = "name"; }) "pewter";
      expected = "A\nR";
    };
    test-g13-captured-and-scope-segments-resolve = {
      expr = {
        captured =
          builtins.attrNames
            (grammar {
              captured = "node";
              path = [ "name" ];
            }).realized.c.pewter;
        scope =
          builtins.attrNames
            (grammar {
              scope = "node";
              path = [ "shade" ];
            }).realized.c.pewter;
      };
      expected = {
        captured = [
          "damask"
          "pewter"
        ];
        scope = [
          "damask-shade"
          "pewter"
        ];
      };
    };
    # Each segment is one an admitting mutant would RESOLVE, so admission delivers rather than
    # failing on a malformed segment: the default names an absent binding, the conditional has both
    # branches. RED: a mutant admitting a function, a default, a conditional or a foreign attrset
    # segment delivers.
    test-g13-function-attrset-conditional-and-default-segments-refuse = {
      expr = map (seg: ok (grammar seg).realized.c.pewter) [
        (_: "pewter")
        {
          captured = "absent";
          default = "pewter";
        }
        {
          "if" = true;
          "then" = "pewter";
          "else" = "welt";
        }
        { other = "pewter"; }
        3
      ];
      expected = [
        false
        false
        false
        false
        false
      ];
    };

    # ── G15: undeclared address ──
    # RED: a silent-drop mutant realizes pewter with "R" and no refusal.
    test-g15-class-with-no-terminal-refuses = {
      expr = ok noTerminal.realized.c;
      expected = false;
    };
    test-g15-node-not-in-the-projection-refuses = {
      expr = ok noNode.projected;
      expected = false;
    };

    # ── C2: consumed vs dropped ──
    # o1 routed, o2 left in a cell with no terminal: the realization refuses (o2 would be dropped).
    # RED: the class-wide exemption realizes at rc 0, dropping o2.
    test-c2-unrouted-occurrence-in-a-terminalless-cell-refuses = {
      expr = ok partial.realized;
      expected = false;
    };
    test-c2-consumed-occurrence-is-stripped-from-its-source-cell = {
      expr = oneOcc.projected.nodes.damask.classes.s;
      expected = [ ];
    };
    test-c2-w1-consumed-terminalless-cell-realizes = {
      expr = thread w1Consumed "pewter";
      expected = "A\nB\nR";
    };

    # ── P3: overlapping paths ──
    # Each path module sits at the position of its first occurrence in the received order. On this
    # receiver the native merge between modules at different paths does NOT read that order: both
    # declared orders read one value (measured before the cell was written, two nestings, both
    # orders). The cell pins that value; it does not discriminate a path-sorting mutant, which reads
    # the same here.
    test-p3-overlapping-paths-read-the-native-structural-order = {
      expr = map (sw: thread (overlapping sw) "pewter") [
        false
        true
      ];
      expected = [
        "A\nR\nB"
        "A\nR\nB"
      ];
    };

    # ── G2: native inputs ──
    # RED: a mutant discarding the context leaves the consumer without the source's output.
    test-g2-forwarded-context-reaches-the-consumer = {
      expr = builtins.attrNames (builtins.getContext ctx.realized.c.pewter.pewter.thread);
      expected = [ src.drvPath ];
    };

    # ── G3: optional N / E are reported `unrouted`, silently; the source stays buildable ──
    test-g3-optional-n-and-e-are-unrouted-and-the-check-passes = {
      expr = {
        check = optionalOnly.check;
        unrouted = optionalOnly.diagnostics.unrouted;
        excluded = map (e: e.route) optionalOnly.diagnostics.excluded;
      };
      expected = {
        check = true;
        unrouted = [
          "damask/n2"
          "damask/e2"
        ];
        excluded = [ "damask/e2" ];
      };
    };
    # RED (a check reachable from a target's value): the target's read throws with the check.
    test-g3-source-and-target-evaluate-while-the-check-fails = {
      expr = {
        check = (builtins.tryEval failingCheck.check).success;
        target = failingCheck.realized.c.pewter.pewter.thread;
      };
      expected = {
        check = false;
        target = "A\nR";
      };
    };

    # ── the check, as a value ──
    test-check-passes-on-a-clean-forward = {
      expr = oneOcc.check;
      expected = true;
    };
    # The check fails while an unaffected target still realizes: no target reaches it.
    test-check-is-not-reachable-from-a-target = {
      expr = {
        check = (builtins.tryEval cyc.check).success;
        velour = ok cyc.realized.c.velour;
      };
      expected = {
        check = false;
        velour = true;
      };
    };
  };
}
