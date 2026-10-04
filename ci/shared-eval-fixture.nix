# THE SHARED-EVALUATION FIXTURE (den-hoag-htfv3 U3) — entities a and b (pin p1, delivery class T1)
# and c (pin p2, T2), their instance relation (`instancesFor`), and the desugared cold arm, shared by
# the `elementIds`, map × instances and parity cells in `tests/include-closure.nix`.
#
# Members: a `[ s e w nx ]`, b `[ s e w ]`, c `[ e w ]`. `s` reads the pin, so a and b reach one
# vertex; `e` reads the host, so each entity reaches its own, whose include names the entity's own
# aspect. `w` holds inline content and `nx` carries no class content. Every aspect carries
# `T.marks = [ "<its name>" ]`; the list merge reverses module order, so a value reads
# last-delivered first.
{
  genDelivery,
  aspects,
  genMerge,
  term,
}:
let
  t = genMerge.types;
  inherit (aspects) guard pred;
  cnf.keySemantics.T.category = "class";
  marked = n: { T.marks = [ n ]; };

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
        e = guard (pred.has "host") (
          marked "e"
          // {
            description = "e";
            includes = [ (term.readCtx "host" [ ]) ];
          }
        );
        s = guard (pred.has "pin") (marked "s" // { description = "s"; });
        w = marked "w" // {
          includes = [ { T.marks = [ "inl" ]; } ];
        };
        nx = {
          description = "nx";
          includes = [ "ha" ];
        };
        ha = marked "ha";
        hb = marked "hb";
        hc = marked "hc";
        # one sibling per user descendant, each carrying content
        fan = guard (pred.has "user") (
          marked "fan"
          // {
            includes = [ (term.readCtx "user" [ ]) ];
          }
        );
        uA = marked "uA";
        uB = marked "uB";
      };
      hosts = {
        a.aspects = [
          "s"
          "e"
          "w"
          "nx"
        ];
        b.aspects = [
          "s"
          "e"
          "w"
        ];
        c.aspects = [
          "e"
          "w"
        ];
        f.aspects = [ "fan" ];
      };
    }
  ];

  # A source is an identity (`<kind>:<64 hex>`), never the value it supplies.
  src = n: "entity:${builtins.hashString "sha256" n}";
  suppliers = {
    ${src "a"}.host = "ha";
    ${src "b"}.host = "hb";
    ${src "c"}.host = "hc";
    ${src "p1"}.pin = "p1";
    ${src "p2"}.pin = "p2";
    ${src "u1"}.user = "uA";
    ${src "u2"}.user = "uB";
  };
  ent = n: pin: {
    members = values.hosts.${n}.aspects;
    sources = {
      host = src n;
      pin = src pin;
    };
  };
  scopes = {
    a = ent "a" "p1";
    b = ent "b" "p1";
    c = ent "c" "p2";
    f = {
      members = [ "fan" ];
      sources = { };
      descendants = [
        { sources.user = src "u1"; }
        { sources.user = src "u2"; }
      ];
    };
  };
  relOf =
    v: sc:
    aspects.instancesFor cnf v.aspects {
      inherit suppliers;
      scopes = sc;
    };
  rel = relOf values scopes;
  dc = {
    a = "T1";
    b = "T1";
    c = "T2";
  };
  projectOf =
    v: instances: nodes:
    genDelivery.project {
      values = v;
      inherit cnf instances;
      selectNodes = _: nodes;
      deliveryClasses = builtins.intersectAttrs nodes (builtins.mapAttrs (_: d: { T = d; }) dc);
    };
  abc = builtins.intersectAttrs dc values.hosts;
  marksOf =
    mods:
    (genMerge.evalModuleTree {
      modules = [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ mods;
    }).config.marks;
  shared = projectOf values rel abc;

  # Views the cells read beside the relation, each a defect a producer could ship.
  # `remint`: b's S under a fresh id carrying the same vertex (a per-entity re-mint).
  sA = builtins.head rel.reaches.a.s;
  remint = rel // {
    vertices = rel.vertices // {
      "aspect-instance:remint-b" = rel.vertices.${sA};
    };
    instantiates = rel.instantiates // {
      "aspect-instance:remint-b" = [ "s" ];
    };
    reaches = rel.reaches // {
      b = rel.reaches.b // {
        s = [ "aspect-instance:remint-b" ];
      };
    };
  };
  # `merged`: every entity reads a's E vertex (an instance-key merge).
  merged = rel // {
    reaches = builtins.mapAttrs (_: r: r // { e = rel.reaches.a.e; }) rel.reaches;
  };
  # `rotated`: every E vertex keeps its id and holds another entity's application (a → b → c → a).
  eOf = n: builtins.head rel.reaches.${n}.e;
  rotated = rel // {
    vertices = rel.vertices // {
      ${eOf "a"} = rel.vertices.${eOf "b"};
      ${eOf "b"} = rel.vertices.${eOf "c"};
      ${eOf "c"} = rel.vertices.${eOf "a"};
    };
  };

  # The cold arm (design §4 cell 1): the registry desugared per entity. Each parametric P an entity
  # lists becomes the static `P-<entity>`, P applied to that entity's tuple through gen-aspects' own
  # application (`instanceOf`), named in P's place.
  facts = aspects.graphFacts cnf values.aspects;
  params = [
    "e"
    "s"
  ];
  applied =
    n: p:
    (aspects.instanceOf cnf {
      aspect = p;
      value = facts.nodeData.${p};
      context = builtins.mapAttrs (k: s: suppliers.${s}.${k}) scopes.${n}.sources;
      inherit (scopes.${n}) sources;
    }).entry;
  coldValues = valuesOf [
    {
      aspects =
        values.aspects
        // builtins.listToAttrs (
          builtins.concatMap (
            n:
            map (p: {
              name = "${p}-${n}";
              value = applied n p;
            }) (builtins.filter (p: builtins.elem p params) values.hosts.${n}.aspects)
          ) (builtins.attrNames abc)
        );
      hosts = builtins.mapAttrs (n: h: {
        aspects = map (p: if builtins.elem p params then "${p}-${n}" else p) h.aspects;
      }) abc;
    }
  ];
  cold = projectOf coldValues (relOf coldValues { }) (builtins.intersectAttrs dc coldValues.hosts);
  digest =
    p: n: builtins.hashString "sha256" (builtins.toJSON (marksOf p.nodes.${n}.classes.${dc.${n}}));
  parity = p: builtins.mapAttrs (n: _: digest p n) abc;

  # Each delivery class's terminal stamps its pin and peers.
  terminal =
    pin:
    { modules, extent, ... }:
    {
      inherit pin;
      marks = marksOf modules;
      peers = builtins.attrNames extent;
    };
  realizedOf =
    projected:
    genDelivery.realize {
      inherit projected;
      terminals = {
        T1 = terminal "p1";
        T2 = terminal "p2";
      };
    };
in
{
  inherit
    rel
    shared
    dc
    sA
    eOf
    marksOf
    cold
    parity
    ;
  realized = realizedOf shared;
  remint = projectOf values remint abc;
  merged = projectOf values merged abc;
  rotated = projectOf values rotated abc;
  fanned = projectOf values rel { inherit (values.hosts) f; };
}
