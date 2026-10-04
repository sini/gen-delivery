# THE PARAMETRIC FIXTURE (den-hoag-wpn8c) — one aspect tree, its node set, and gen-aspects' own
# instance relation over them (`instancesFor`), shared by the value cells in
# `tests/include-closure.nix` and the door cells in `tests-error.nix`. It lives outside ./tests
# because every file there is a test module.
#
# Every aspect carries `nixos.marks = [ "<its name>" ]`; the list merge reverses module order, so a
# value reads last-delivered first. Guards of one condition carry distinct `description`s: a guard's
# identity is its term, and two equal terms would be one instance (den-hoag-ehkse), which `collide`
# below exercises on purpose.
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

  valuesOf =
    mods:
    (genMerge.evalModuleTree {
      modules = [
        ((aspects.mkAspectSchema cnf).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
      ]
      ++ mods;
    }).config;

  values = valuesOf [
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
        # The empty reach in a handed scope (K1, interim refusal): `hm` reached directly, and nested
        # inside `eu`.
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
    values: suppliers: scopes:
    aspects.instancesFor cnf values.aspects { inherit suppliers scopes; };
  rel =
    relationOf values
      {
        ${src "na"}.host = "ha";
        ${src "nb"}.host = "hb";
        ${src "nei"}.host = "ha";
        ${src "nh"}.host = "ha";
        ${src "u1"}.user = "uA";
        ${src "u2"}.user = "uB";
      }
      {
        na = host "na" // {
          members = values.hosts.na.aspects;
        };
        nb = host "nb" // {
          members = values.hosts.nb.aspects;
        };
        nf = {
          members = [ "fan" ];
          sources = { };
          descendants = [
            { sources.user = src "u1"; }
            { sources.user = src "u2"; }
          ];
        };
        nei = host "nei" // {
          members = [ "ei" ];
        };
        # `nmiss` is handed no scope: its relation entry is absent.
        nh = host "nh" // {
          members = [ "home" ];
        };
        nhu = host "nh" // {
          members = [ "home" ];
          descendants = [ { sources.user = src "u1"; } ];
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
    (genMerge.evalModuleTree {
      modules = [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ projected.nodes.${n}.classes.nixos;
    }).config.marks;
  projectWith = projectOf values;
  withView =
    view:
    marksOf (projectWith {
      instances = view;
    });
  iidOf = n: a: builtins.head rel.reaches.${n}.${a};

  # den-hoag-ehkse: two guards whose condition and non-class body are equal mint ONE instance, which
  # `instancesFor` lists under both declarations. `distinct` is the control: distinct descriptions.
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
      r = relationOf v { ${src "n"}.host = "n"; } {
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
  inherit
    rel
    projectWith
    marksOf
    withView
    iidOf
    ;
  withRel = projectWith { instances = rel; };
  noRel = projectWith { };
  mW = withView rel;
  collide = collideOf (_: { });
  distinct = collideOf (n: {
    description = n;
  });
}
