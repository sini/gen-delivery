# THE PARAMETRIC FIXTURE (den-hoag-wpn8c) — one aspect tree, its node set, and gen-aspects' own
# instance relation over them (`instancesFor`), shared by the value cells in
# `tests/include-closure.nix` and the door cells in `tests-error.nix`. It lives outside ./tests
# because every file there is a test module.
#
# Every aspect carries `nixos.marks = [ "<its name>" ]`; the list merge reverses module order, so a
# value reads last-delivered first. Guards of one condition carry distinct `description`s, though a
# placed guard is identified by its declared path and not by its term (den-hoag-ehkse): `collide`
# below holds two equal terms at two paths.
{
  genDelivery,
  aspects,
  genMerge,
  term,
}:
let
  t = genMerge.types;
  inherit (aspects) guard pred;
  cnf.keySemantics.nixos.category = "class";
  marked = n: { nixos.marks = [ n ]; };
  hostGuard = n: guard (pred.has "host") (marked n // { description = n; });

  valuesOf = valuesWith cnf;
  valuesWith =
    c: mods:
    (genMerge.evalModuleTree { } (
      [
        ((aspects.mkAspectSchema c).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
      ]
      ++ mods
    )).config;

  values = valuesOf mods;
  mods = [
    {
      aspects = {
        web = marked "web" // {
          includes = [ "e" ];
        };
        # Each instance's context-computed include names its own host (W1).
        e = guard (pred.has "host") (
          marked "e"
          // {
            includes = [
              "q"
              (term.readCtx "host" [ ])
            ];
          }
        );
        q = hostGuard "q";
        ha = marked "ha";
        # A static node reached inside an instance body: its parametric include resolves at NODE scope (W6).
        hb = marked "hb" // {
          includes = [ "r" ];
        };
        r = hostGuard "r";
        p = hostGuard "p";
        # Fans out to every descendant that admits it (W7).
        fan = guard (pred.has "user") { includes = [ (term.readCtx "user" [ ]) ]; };
        uA = marked "uA";
        uB = marked "uB";
        c = marked "c";
        # Inline content inside an instance body, holding a parametric include (W5b).
        ei = guard (pred.has "host") {
          includes = [
            {
              nixos.marks = [ "ei-inline" ];
              includes = [ "q" ];
            }
          ];
        };
        # The empty reach in a handed scope (den-hoag-n8wb5): `hm` reached directly, and nested inside
        # `eu`; declined under the closed world, refused (R) under the open world.
        hm = guard (pred.has "user") (marked "hm" // { description = "hm"; });
        home = marked "home" // {
          includes = [ "hm" ];
        };
        eu = guard (pred.has "host") (
          marked "eu"
          // {
            includes = [ "hm" ];
          }
        );
      };
    }
    # A split aspect: a static part beside a guard part folds into a guard carrier (G9j).
    { aspects.s = marked "attr"; }
    { aspects.s = guard (pred.has "host") (marked "guard"); }
    {
      hosts = {
        na.aspects = [
          "web"
          "p"
          "s"
        ];
        nb.aspects = [ "web" ];
        nf.aspects = [ "fan" ];
        nfr.aspects = [ "fan" ];
        nmiss.aspects = [ "p" ];
        nc.aspects = [ "c" ];
        nei.aspects = [ "ei" ];
        nh.aspects = [ "home" ];
        nhu.aspects = [ "home" ];
        nhe.aspects = [ "eu" ];
        # A TRUE guard whose member the handed scope omits (`nomit`), beside the same scope with it.
        nomit.aspects = [ "p" ];
        nhanded.aspects = [ "p" ];
      };
    }
  ];

  # A source is an identity (`<kind>:<64 hex>`), never the value it supplies.
  src = n: "entity:${builtins.hashString "sha256" n}";
  host = n: { sources.host = src n; };
  relationOf =
    values: suppliers: containment: scopes:
    aspects.instancesFor cnf values.aspects {
      inherit suppliers;
      inherit containment;
    } scopes;
  # The entity graph's one-step containment (den-hoag-8g2rn). `fan` fans over a host's users in the
  # users' IDENTIFIER order: nfH holds u1 (uA) and u2 (uB); nfrH holds the same values under
  # identifiers in the other order, w1 (uB) and w2 (uA), the renamed arm (W7). nhuH holds the one
  # user `nhu` reaches.
  rec0 = parent: key: x: {
    inherit parent key;
    identity = src x;
    marked = false;
    bindings = { };
  };
  containment = {
    nfH = rec0 null "host" "nfH";
    u1 = rec0 "nfH" "user" "u1";
    u2 = rec0 "nfH" "user" "u2";
    nfrH = rec0 null "host" "nfrH";
    w1 = rec0 "nfrH" "user" "u2r";
    w2 = rec0 "nfrH" "user" "u1r";
    nhuH = rec0 null "host" "nhuH";
    u3 = rec0 "nhuH" "user" "u3";
  };
  rel = relationOf values relInput.suppliers containment relInput.scopes;
  relInput = {
    suppliers = {
      ${src "na"}.host = "ha";
      ${src "nb"}.host = "hb";
      ${src "nei"}.host = "ha";
      ${src "nh"}.host = "ha";
      ${src "u1"}.user = "uA";
      ${src "u2"}.user = "uB";
      ${src "u1r"}.user = "uA";
      ${src "u2r"}.user = "uB";
      ${src "u3"}.user = "uA";
      ${src "nfH"}.host = "hf";
      ${src "nfrH"}.host = "hf";
      ${src "nhuH"}.host = "ha";
    };
    scopes = {
      na = host "na" // {
        members = values.hosts.na.aspects;
      };
      nb = host "nb" // {
        members = values.hosts.nb.aspects;
      };
      nf = host "nfH" // {
        members = [ "fan" ];
      };
      # `nf`'s values under identifiers in the other order (W7's renamed arm).
      nfr = host "nfrH" // {
        members = [ "fan" ];
      };
      nei = host "nei" // {
        members = [ "ei" ];
      };
      # `nmiss` is handed no scope: its relation entry is absent.
      nh = host "nh" // {
        members = [ "home" ];
      };
      nhu = host "nhuH" // {
        members = [ "home" ];
      };
      nhe = host "nh" // {
        members = [ "eu" ];
      };
      nomit = host "nh" // {
        members = [ ];
      };
      nhanded = host "nh" // {
        members = [ "p" ];
      };
    };
  };

  # The same tree and scopes under the CLOSED world (a declared coordinate set): an absent `user`
  # resolves FALSE, so the relation declines the guard (den-hoag-n8wb5). Under the open world above
  # the evaluator refuses it (R), so it is in neither set.
  cnfCw = cnf // {
    entityKinds = {
      host = true;
      user = true;
    };
  };
  # A guard is checked and fired under ONE declared set, so the closed world places its own tree.
  valuesCw = valuesWith cnfCw mods;
  relCw = aspects.instancesFor cnfCw valuesCw.aspects {
    suppliers = relInput.suppliers;
    inherit containment;
  } relInput.scopes;
  # ADR-0019's equivalence: the same closed-world tree with `home`'s include of `hm` removed, so `nh`
  # projects there what an include that never existed delivers.
  valuesCwNoHm = valuesWith cnfCw (
    map (
      m:
      if m ? aspects.home then
        m
        // {
          aspects = m.aspects // {
            home = marked "home";
          };
        }
      else
        m
    ) mods
  );
  withoutHmCw = projectOf valuesCwNoHm {
    cnf = cnfCw;
    instances = aspects.instancesFor cnfCw valuesCwNoHm.aspects {
      suppliers = relInput.suppliers;
      inherit containment;
    } relInput.scopes;
  };
  withViewCw =
    view:
    marksOf (
      projectOf valuesCw {
        cnf = cnfCw;
        instances = view;
      }
    );
  projectOf =
    values: extra:
    genDelivery.project (
      {
        inherit values cnf;
        selectNodes = v: v.hosts;
      }
      // extra
    );
  marksOf =
    projected: n:
    (genMerge.evalModuleTree { } (
      [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ projected.nodes.${n}.classes.nixos
    )).config.marks;
  projectWith = projectOf values;
  withView =
    view:
    marksOf (projectWith {
      instances = view;
    });
  iidOf = n: a: builtins.head rel.reaches.${n}.${a};

  # den-hoag-ehkse: two guards whose condition and non-class body are equal are two declarations, so
  # two instances, each delivering its own marks. `distinct` is the control: distinct descriptions.
  collideOf =
    described:
    let
      v = valuesOf [
        {
          aspects.x = guard (pred.has "host") (marked "x" // described "x");
          aspects.y = guard (pred.has "host") (marked "y" // described "y");
          hosts.n.aspects = [
            "x"
            "y"
          ];
        }
      ];
      r = relationOf v { ${src "n"}.host = "n"; } { } {
        n = host "n" // {
          members = [
            "x"
            "y"
          ];
        };
      };
    in
    {
      rel = r;
      marks = marksOf (projectOf v { instances = r; }) "n";
    };
in
{
  # A named aspect's facts id, read from the facts and not from `project`'s output.
  factIdOf = k: (aspects.graphFacts cnf values.aspects).nodeIdOf.${k};
  inherit
    rel
    projectWith
    marksOf
    withView
    iidOf
    ;
  withRel = projectWith { instances = rel; };
  inherit relCw withViewCw withoutHmCw;
  mCw = withViewCw relCw;
  withRelCw = projectOf valuesCw {
    cnf = cnfCw;
    instances = relCw;
  };
  noRel = projectWith { };
  mW = withView rel;
  collide = collideOf (_: { });
  distinct = collideOf (n: {
    description = n;
  });
}
