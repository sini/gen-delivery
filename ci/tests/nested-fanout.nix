# What `project` delivers at host and user nodes when a parametric include fans out over containment
# descendants (gen-aspects `instancesFor`, den-hoag-8g2rn: rulings 7 and 13, and the 8g2rn rulings
# S3c, T1 and K-c amended to SHADOW). The relation's nested edges are per reading node
# (`nestedAt.<node>.<iid>`), read through one shared lift.
#
# DEN V1 PARITY. Each shape's per-entity values match den v1 (`~/Documents/repos/denful/den` 7e43b21,
# re-run through its `denTest` harness: reports/den-hoag-8g2rn-spec-v1.probes/out/denv1-*.txt in
# den-ag-design) at the host node n (host a) and the user nodes m (a, u1) and mu2 (a, u2):
#   DIRECT {host} ⊃ {user}              host: tux, pingu   u1: tux       u2: pingu
#   STATIC {host} ⊃ static ⊃ {user}     as DIRECT
#   TWO    {host} ⊃ {user} ⊃ {dot}      host: the users, no dots        u1: tux, d1   u2: pingu, d2
#   SKIP   {host} ⊃ {dot}               host: none        u1: d1        u2: d2
#   UD     {host} ⊃ {user, dot}         host: (tux d1), (pingu d2)      u1: d1        u2: d2
#   all-users                           host: every user  u1: tux only
# Containment: a ⊃ u1 ⊃ d1, a ⊃ u2 ⊃ d2; c ⊃ w1 ⊃ e1, c ⊃ w2.
{
  aspects,
  genDelivery,
  genMerge,
  term,
  ...
}:
let
  t = genMerge.types;
  inherit (aspects) guard pred;
  has = pred.has;
  marked = n: { nixos.marks = [ n ]; };
  reads = k: { includes = [ (term.readCtx k [ ]) ]; };
  defs = {
    pinU = guard (has "user") (reads "user");
    pinD = guard (has "dot") (reads "dot");
    innerUD = guard (pred.all [
      (has "user")
      (has "dot")
    ]) (reads "dot");
    pmid.includes = [ "pinU" ];
    pmidU = guard (has "user") {
      includes = [
        "pinD"
        (term.readCtx "user" [ ])
      ];
    };
    sD.includes = [ "pinD" ];
    pDIRECT = guard (has "host") { includes = [ "pinU" ]; };
    pSTATIC = guard (has "host") { includes = [ "pmid" ]; };
    pTWO = guard (has "host") { includes = [ "pmidU" ]; };
    pSKIP = guard (has "host") { includes = [ "pinD" ]; };
    pSKIPS = guard (has "host") { includes = [ "sD" ]; };
    pUD = guard (has "host") { includes = [ "innerUD" ]; };
  }
  // builtins.listToAttrs (
    map
      (v: {
        name = "v-${v}";
        value = marked "v-${v}";
      })
      [
        "u1"
        "u2"
        "d1"
        "d2"
        "e1"
        "w1"
        "w2"
      ]
  );
  cnfOf =
    declared:
    {
      keySemantics.nixos.category = "class";
    }
    // (
      if declared then
        {
          entityKinds = {
            site = true;
            host = true;
            user = true;
            dot = true;
          };
        }
      else
        { }
    );
  valuesOf =
    cnf:
    (genMerge.evalModuleTree { } [
      ((aspects.mkAspectSchema cnf).mkAspectModule { })
      { aspects = defs; }
    ]).config;
  src = n: "entity:${builtins.hashString "sha256" n}";
  key = {
    a = "host";
    c = "host";
    s0 = "site";
    u1 = "user";
    u2 = "user";
    w1 = "user";
    w2 = "user";
    d1 = "dot";
    d2 = "dot";
    e1 = "dot";
  };
  suppliers = builtins.listToAttrs (
    map (x: {
      name = src x;
      value.${key.${x}} = "v-${x}";
    }) (builtins.attrNames key)
  );
  rec0 = parent: x: {
    inherit parent;
    key = key.${x};
    identity = src x;
    marked = false;
    bindings = { };
  };
  containment = {
    a = rec0 null "a";
    u1 = rec0 "a" "u1";
    u2 = rec0 "a" "u2";
    d1 = rec0 "u1" "d1";
    d2 = rec0 "u2" "d2";
    c = rec0 null "c";
    w1 = rec0 "c" "w1";
    w2 = rec0 "c" "w2";
    e1 = rec0 "w1" "e1";
  };
  nodeSources = {
    n.host = src "a";
    m = {
      host = src "a";
      user = src "u1";
    };
    mu2 = {
      host = src "a";
      user = src "u2";
    };
    nc.host = src "c";
    mw1 = {
      host = src "c";
      user = src "w1";
    };
    mw2 = {
      host = src "c";
      user = src "w2";
    };
  };
  # `project` over `nodes`, each reading `shape`; the per-entity values each node receives, sorted
  # (the parity is membership; order is ruling 13's and W7's)
  projected =
    {
      shape,
      nodes ? [
        "n"
        "m"
        "mu2"
      ],
      declared ? true,
      cEdit ? (c: c),
    }:
    let
      cnf = cnfOf declared;
      values = valuesOf cnf;
      instances =
        aspects.instancesFor cnf values.aspects
          {
            inherit suppliers;
            containment = cEdit containment;
          }
          (
            builtins.listToAttrs (
              map (nd: {
                name = nd;
                value = {
                  members = [ shape ];
                  sources = nodeSources.${nd};
                };
              }) nodes
            )
          );
    in
    {
      inherit instances;
      p =
        genDelivery.project
          {
            selectNodes = vs: vs.nodes;
            inherit instances;
          }
          cnf
          (
            values
            // {
              nodes = builtins.listToAttrs (
                map (nd: {
                  name = nd;
                  value.aspects = [ shape ];
                }) nodes
              );
            }
          );
    };
  valuesAt =
    args:
    let
      inherit (projected args) p;
    in
    builtins.mapAttrs (
      nd: _:
      builtins.sort builtins.lessThan (
        builtins.filter (x: builtins.substring 0 2 x == "v-") (
          (genMerge.evalModuleTree { } (
            [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ p.nodes.${nd}.classes.nixos or [ ]
          )).config.marks or [ ]
        )
      )
    ) p.nodes;
  refuses = x: !(builtins.tryEval (builtins.deepSeq x x)).success;
  bothUsers = [
    "v-u1"
    "v-u2"
  ];
in
{
  flake.tests.nested-fanout = {
    # DIRECT and all-users: every user at the host, only its own at a user's node. RED (S1, fan-out at
    # the vertex alone): m and mu2 receive both users.
    test-direct-parity = {
      expr = {
        declared = valuesAt { shape = "pDIRECT"; };
        open = valuesAt {
          shape = "pDIRECT";
          declared = false;
        };
      };
      expected =
        let
          v = {
            n = bothUsers;
            m = [ "v-u1" ];
            mu2 = [ "v-u2" ];
          };
        in
        {
          declared = v;
          open = v;
        };
    };
    # STATIC: a static hop changes nothing. RED (S1): as DIRECT's.
    test-static-parity = {
      expr = valuesAt { shape = "pSTATIC"; };
      expected = {
        n = bothUsers;
        m = [ "v-u1" ];
        mu2 = [ "v-u2" ];
      };
    };
    # TWO: no dots at the host (declined in the declared world, refused by name in the open one),
    # each user's dot at its node. RED (`seed-own`): d1, d2 at the host; (S1): both dots at each user.
    test-two-levels-parity = {
      expr = {
        declared = valuesAt { shape = "pTWO"; };
        hostOpenRefuses =
          refuses
            (valuesAt {
              shape = "pTWO";
              nodes = [ "n" ];
              declared = false;
            }).n;
        usersOpen = valuesAt {
          shape = "pTWO";
          nodes = [
            "m"
            "mu2"
          ];
          declared = false;
        };
      };
      expected = {
        declared = {
          n = bothUsers;
          m = [
            "v-d1"
            "v-u1"
          ];
          mu2 = [
            "v-d2"
            "v-u2"
          ];
        };
        hostOpenRefuses = true;
        usersOpen = {
          m = [
            "v-d1"
            "v-u1"
          ];
          mu2 = [
            "v-d2"
            "v-u2"
          ];
        };
      };
    };
    # SKIP, directly and through a static hop: nothing at the host, each user's dot at its node. RED
    # (`seed-own`): d1, d2 at the host; (S1): both dots at each user.
    test-skip-parity = {
      expr = {
        direct = valuesAt { shape = "pSKIP"; };
        static = valuesAt { shape = "pSKIPS"; };
        hostOpenRefuses =
          refuses
            (valuesAt {
              shape = "pSKIP";
              nodes = [ "n" ];
              declared = false;
            }).n;
      };
      expected =
        let
          v = {
            n = [ ];
            m = [ "v-d1" ];
            mu2 = [ "v-d2" ];
          };
        in
        {
          direct = v;
          static = v;
          hostOpenRefuses = true;
        };
    };
    # UD: a co-destructured {user, dot} aspect fans over the pairs at the host.
    test-co-destructured-parity = {
      expr = valuesAt { shape = "pUD"; };
      expected = {
        n = [
          "v-d1"
          "v-d2"
        ];
        m = [ "v-d1" ];
        mu2 = [ "v-d2" ];
      };
    };
    # T1 rule (b) (gate C1): a level ABOVE the host node's entity is not crossed. RED (v1.1): `n` = [].
    test-a-level-above-the-host-is-not-crossed = {
      expr = valuesAt {
        shape = "pDIRECT";
        cEdit =
          c:
          c
          // {
            s0 = rec0 null "s0";
            a = c.a // {
              parent = "s0";
            };
          };
      };
      expected = {
        n = bothUsers;
        m = [ "v-u1" ];
        mu2 = [ "v-u2" ];
      };
    };
    # DECLAT: the decline is per node. At the dotless user w2's node the dot is declined; at w1's, its
    # dot; at the host, no dot (T1). RED (`gd-seed-vdecl`, `project` ignoring the per-node decline):
    # the undecided door at mw2.
    test-decline-is-per-node = {
      expr = valuesAt {
        shape = "pSKIP";
        nodes = [
          "nc"
          "mw1"
          "mw2"
        ];
      };
      expected = {
        nc = [ ];
        mw1 = [ "v-e1" ];
        mw2 = [ ];
      };
    };
    # The relation's nested edges are per node: one shared `pDIRECT@a` vertex, its `pinU` edges both
    # users at n and one at m. RED (a vertex-keyed `nested`, S1): one list for both nodes.
    test-nested-edges-are-per-node = {
      expr =
        let
          r = (projected { shape = "pDIRECT"; }).instances;
          v = builtins.head r.reaches.n.pDIRECT;
        in
        {
          shared = r.reaches.m.pDIRECT == [ v ];
          n = builtins.length r.nestedAt.n.${v}.pinU;
          m = builtins.length r.nestedAt.m.${v}.pinU;
        };
      expected = {
        shared = true;
        n = 2;
        m = 1;
      };
    };
  };
}
