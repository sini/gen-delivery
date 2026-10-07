# ANONYMOUS DECLARATIONS ARE DELIVERED AS NODES (den-hoag-8hlo3; identity design 2026-09-30 §2, §3,
# §4 row 1).
#
# gen-aspects publishes inline include content as nodes keyed by their declaration, and an applied
# body's content under its instance (`<iid>/includes/<i>`). `project` reaches each as the node it is:
# the walk delivers it at its include slot, the lifted graph holds it as a vertex, the parity door
# counts it, and `elementIds` names it. What a node RECEIVES does not move: every arm below reads the
# realized marks, and each one equals what the tree delivered before the content was a node.
{
  genDeliveryWith,
  scope,
  aspects,
  genMerge,
  ...
}:
let
  inherit (aspects) guard pred;
  t = genMerge.types;
  cnf.keySemantics.T.category = "class";
  marked = n: { T.marks = [ n ]; };
  ev =
    mods:
    (genMerge.evalModuleTree { } (
      [
        ((aspects.mkAspectSchema cnf).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
      ]
      ++ mods
    )).config;
  hostsXY = x: y: {
    hosts.x.aspects = [ x ];
    hosts.y.aspects = [ y ];
  };

  hasInfix = i: s: builtins.length (builtins.split i s) > 1;
  # `scope` with every answer whose node holds `drop` removed: a query that does not reach them.
  dropping =
    drop:
    scope
    // {
      resolve =
        o: s: from:
        let
          r = scope.resolve o s from;
        in
        r // { answers = builtins.filter (a: !(hasInfix drop a.node)) r.answers; };
    };
  src = n: "entity:${builtins.hashString "sha256" n}";
  projectOver =
    sc: values:
    (genDeliveryWith sc).project {
      inherit values cnf;
      instances =
        aspects.instancesFor cnf values.aspects
          {
            suppliers = builtins.listToAttrs (
              map (h: {
                name = src h;
                value.host = "h${h}";
              }) (builtins.attrNames values.hosts)
            );
            containment = { };
          }
          (
            builtins.mapAttrs (h: v: {
              members = v.aspects;
              sources.host = src h;
            }) values.hosts
          );
      selectNodes = _: values.hosts;
    };
  project = projectOver scope;
  # A static tree under an empty relation (no scope reads it), so a refusal in one aspect's sites is
  # met only by a host that reaches that aspect.
  projectStatic =
    values:
    (genDeliveryWith scope).project {
      inherit values cnf;
      instances = aspects.instancesFor cnf values.aspects {
        suppliers = { };
        containment = { };
      } { };
      selectNodes = _: values.hosts;
    };

  try =
    v:
    let
      r = builtins.tryEval (builtins.deepSeq v v);
    in
    if r.success then r.value else "REFUSED";
  # A class key's content is a deferred module: its marks are read through each `imports` layer.
  marksIn =
    m:
    if builtins.isAttrs m then
      (m.marks or [ ]) ++ builtins.concatMap marksIn (m.imports or [ ])
    else
      [ ];
  marksOf = p: h: try (builtins.concatMap marksIn p.nodes.${h}.classes.T);
  xy = values: {
    x = marksOf (projectStatic values) "x";
    y = marksOf (projectStatic values) "y";
  };

  # Static inline content, nested content and a named target inside it; one let-bound literal at two
  # owners; a parametric aspect whose applied body holds a literal, reached by two entities.
  shared = marked "shared";
  equiv = ev [
    {
      aspects = {
        w = marked "w" // {
          includes = [
            (
              marked "inl"
              // {
                includes = [
                  (marked "inn")
                  "z"
                ];
              }
            )
            shared
          ];
        };
        v = marked "v" // {
          includes = [ shared ];
        };
        z = marked "z";
        e = guard (pred.has "host") (
          marked "e"
          // {
            includes = [ (marked "einl") ];
          }
        );
      };
      hosts = {
        a.aspects = [
          "w"
          "e"
        ];
        b.aspects = [
          "v"
          "e"
        ];
      };
    }
  ];
  equivP = project equiv;
  idsOf = p: h: p.nodes.${h}.elementIds.T;
  # The instance `h` reaches, and its applied body's literal.
  instanceOf =
    h:
    builtins.head (
      builtins.filter (i: builtins.match "aspect-instance:[0-9a-f]+" i != null) (idsOf equivP h)
    );
  applied = h: "${instanceOf h}/includes/0";

  other = ev [ { aspects.a.includes = [ (marked "o") ]; } ];
  other2 = ev [ { aspects.a.includes = [ (marked "o2") ]; } ];
  nestedSrc = ev [
    {
      aspects.a.includes = [
        (
          marked "p"
          // {
            includes = [ (marked "q") ];
          }
        )
      ];
    }
  ];
  cyc =
    let
      s = marked "s" // {
        includes = [ s ];
      };
    in
    s;
  named = {
    name = "t";
    T.marks = [ "t" ];
  };
  mk = m: {
    name = "t";
    T.marks = [ m ];
  };
in
{
  # A3. The query reaches each anonymous declaration and the parity door certifies it: removing the
  # static content's ids, or the applied body's, from `resolve`'s answers refuses by the door's
  # "missing" arm, naming the id. RED (content no vertex, as before): the same removals read rc 0
  # with the output unchanged. CONTROL: removing the named `z` refuses at every arm.
  flake.tests.anonymous-nodes.test-the-query-reaches-anonymous-declarations = {
    expr = {
      static = marksOf (projectOver (dropping "w/includes/") equiv) "a";
      applied = marksOf (projectOver (dropping "/includes/0") equiv) "b";
      control = marksOf (projectOver (dropping "z") equiv) "a";
      unchanged = marksOf equivP "b";
    };
    expected = {
      static = "REFUSED";
      applied = "REFUSED";
      control = "REFUSED";
      unchanged = [
        "v"
        "e"
        "shared"
        "einl"
      ];
    };
  };

  # A4 + A5. Every reached element carries its id, `null` nowhere: the static literals under their
  # declaration ids, the applied body's under its instance. One let-bound literal at two owners is
  # two ids, and two instances' body literals are two ids. RED (inline content no node): the four
  # content positions read `null`.
  flake.tests.anonymous-nodes.test-every-delivered-element-is-named = {
    expr = {
      a = idsOf equivP "a";
      b = idsOf equivP "b";
      twoInstances = applied "a" != applied "b";
    };
    expected = {
      # breadth-first: the members, then each one's includes at its slot
      a = [
        "w"
        (instanceOf "a")
        "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",0]"
        "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",1]"
        (applied "a")
        "w/includes/[\"a:2\",\"aspects\",\"w\",\"includes\",0,\"imports\",0,\"includes\",0]"
        "z"
      ];
      b = [
        "v"
        (instanceOf "b")
        "v/includes/[\"a:2\",\"aspects\",\"v\",\"includes\",0]"
        (applied "b")
      ];
      twoInstances = true;
    };
  };

  # A4's copy arm (identity design Q1; the gate's C1). Each host receives the content its reached
  # aspects wrote, for every route a typed content value reaches a second position. RED (a copy keyed
  # by its source's key): `copyEdit` x = h, `copyEditRev` y = edited, `copyOther` x = h, `copyTwo`
  # x = o, `copyLet` x = h, `copyMerge` x = m0,h, `copyNested` x = h,hn.
  flake.tests.anonymous-nodes.test-each-host-receives-what-it-reached = {
    expr = {
      copyOther = xy (ev [
        (
          {
            aspects.a.includes = [ (marked "h") ];
            aspects.b.includes = [ (builtins.head other.aspects.a.includes) ];
          }
          // hostsXY "b" "a"
        )
      ]);
      copyEdit = xy (ev [
        (
          { config, ... }:
          {
            aspects.a.includes = [ (marked "h") ];
            aspects.b.includes = [ ((builtins.head config.aspects.a.includes) // marked "edited") ];
          }
          // hostsXY "b" "a"
        )
      ]);
      copyEditRev = xy (ev [
        (
          { config, ... }:
          {
            aspects.b.includes = [ (marked "h") ];
            aspects.a.includes = [ ((builtins.head config.aspects.b.includes) // marked "edited") ];
          }
          // hostsXY "a" "b"
        )
      ]);
      copyPlain = xy (ev [
        (
          { config, ... }:
          {
            aspects.a.includes = [ (marked "h") ];
            aspects.b.includes = [ (builtins.head config.aspects.a.includes) ];
          }
          // hostsXY "b" "a"
        )
      ]);
      copyLet = xy (ev [
        (
          { config, ... }:
          let
            e = builtins.head config.aspects.a.includes;
          in
          {
            aspects.a.includes = [ (marked "h") ];
            aspects.b.includes = [ (e // marked "let") ];
          }
          // hostsXY "b" "a"
        )
      ]);
      copyMerge = xy (ev [
        (
          { config, ... }:
          {
            aspects.a.includes = [ (marked "h") ];
            aspects.b.includes = genMerge.mkMerge [
              [ (marked "m0") ]
              [ ((builtins.head config.aspects.a.includes) // marked "merged") ]
            ];
          }
          // hostsXY "b" "a"
        )
      ]);
      copyTwo = xy (ev [
        (
          {
            aspects.b.includes = [
              (builtins.head other.aspects.a.includes)
              (builtins.head other2.aspects.a.includes)
            ];
          }
          // hostsXY "b" "b"
        )
      ]);
      copyNested = xy (ev [
        (
          {
            aspects.a.includes = [
              (
                marked "h"
                // {
                  includes = [ (marked "hn") ];
                }
              )
            ];
            aspects.b.includes = [ (builtins.head nestedSrc.aspects.a.includes) ];
          }
          // hostsXY "b" "a"
        )
      ]);
    };
    expected = {
      copyOther = {
        x = [ "o" ];
        y = [ "h" ];
      };
      copyEdit = {
        x = [ "edited" ];
        y = [ "h" ];
      };
      copyEditRev = {
        x = [ "edited" ];
        y = [ "h" ];
      };
      copyPlain = {
        x = [ "h" ];
        y = [ "h" ];
      };
      copyLet = {
        x = [ "let" ];
        y = [ "h" ];
      };
      copyMerge = {
        x = [
          "m0"
          "merged"
        ];
        y = [ "h" ];
      };
      copyTwo = {
        x = [
          "o"
          "o2"
        ];
        y = [
          "o"
          "o2"
        ];
      };
      copyNested = {
        x = [
          "p"
          "q"
        ];
        y = [
          "h"
          "hn"
        ];
      };
    };
  };

  # A7 (design §4 row 1, "it stays lazy"). A cyclic literal at an aspect no entity reaches changes
  # nothing an entity receives; reaching it refuses by name. RED (eager whole-graph refusal): every
  # host REFUSED. CONTROL: the same tree with a finite literal.
  flake.tests.anonymous-nodes.test-an-unreached-cyclic-literal-changes-nothing = {
    expr = {
      cyclic = xy (ev [
        (
          {
            aspects.a.includes = [ cyc ];
            aspects.b.includes = [ (marked "bl") ];
          }
          // hostsXY "b" "b"
        )
      ]);
      cyclicReach = xy (ev [
        (
          {
            aspects.a.includes = [ cyc ];
            aspects.b.includes = [ (marked "bl") ];
          }
          // hostsXY "a" "b"
        )
      ]);
      control = xy (ev [
        (
          {
            aspects.a.includes = [ (marked "fine") ];
            aspects.b.includes = [ (marked "bl") ];
          }
          // hostsXY "b" "b"
        )
      ]);
    };
    expected = {
      cyclic = {
        x = [ "bl" ];
        y = [ "bl" ];
      };
      cyclicReach = {
        x = "REFUSED";
        y = [ "bl" ];
      };
      control = {
        x = [ "bl" ];
        y = [ "bl" ];
      };
    };
  };

  # K1 and K3 through `project`. Named content is delivered at its position, exactly as before, by
  # every route to one named site; a host reaching none of it (`y`, which reaches only `c`) is
  # untouched. An unnamed element writing `meta.loc` refuses at the host that reaches it, and only
  # there. RED (named content keyed into the node set): every named arm's `x` and `y` REFUSED; (the
  # stamp skips an authored `meta.loc`): `forgeLoc`'s `y` REFUSED, the node set refusing whole.
  flake.tests.anonymous-nodes.test-named-content-and-authored-loc-stay-at-their-site =
    let
      victimSeg = builtins.toJSON [
        "a:2"
        "aspects"
        "a"
        "includes"
        0
      ];
      forged = {
        meta.loc = [
          "a"
          "includes"
          victimSeg
        ];
      }
      // marked "forged";
    in
    {
      expr = {
        namedDup = xy (ev [
          (
            {
              aspects.c = marked "c";
              aspects.a.includes = [
                named
                named
              ];
            }
            // hostsXY "a" "c"
          )
        ]);
        namedFactory = xy (ev [
          (
            {
              aspects.c = marked "c";
              aspects.a.includes = [
                (mk "1")
                (mk "2")
              ];
            }
            // hostsXY "a" "c"
          )
        ]);
        namedTwoMods = xy (ev [
          (
            {
              aspects.c = marked "c";
              aspects.a.includes = [ named ];
            }
            // hostsXY "a" "c"
          )
          { aspects.a.includes = [ named ]; }
        ]);
        # The forging element at its victim's own owner: the host reaching it refuses, and `y`, which
        # reaches only `c`, is untouched.
        forgeLoc = xy (ev [
          (
            {
              aspects.c = marked "c";
              aspects.a.includes = [
                (marked "1")
                forged
              ];
            }
            // hostsXY "a" "c"
          )
        ]);
        # CONTROL: the same write at another owner refuses there (its chain contradicts its loc), with
        # or without the element refusal.
        forgeLocOther = xy (ev [
          (
            {
              aspects.a.includes = [ (marked "1") ];
              aspects.b.includes = [ forged ];
            }
            // hostsXY "a" "b"
          )
        ]);
      };
      expected = {
        namedDup = {
          x = [
            "t"
            "t"
          ];
          y = [ "c" ];
        };
        namedFactory = {
          x = [
            "1"
            "2"
          ];
          y = [ "c" ];
        };
        namedTwoMods = {
          x = [
            "t"
            "t"
          ];
          y = [ "c" ];
        };
        forgeLoc = {
          x = "REFUSED";
          y = [ "c" ];
        };
        forgeLocOther = {
          x = [ "1" ];
          y = "REFUSED";
        };
      };
    };
}
