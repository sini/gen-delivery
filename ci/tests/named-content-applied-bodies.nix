# A NAMED VALUE IN AN APPLIED BODY IS DELIVERED AS ITS CLASS'S NODE
# (den-hoag-named-include-instance-bodies-sfkyy; identity design 2026-09-30 §2, Q5 "yes").
#
# gen-aspects classes a named value's sightings across the static tree and every vertex of the
# relation (`includeSitesOfInstance cnf aspects instances iid`), so `project` reaches one node however
# many instances, or static takers, hold the value: a host reaching two of them receives the content
# once, and `elementIds` names one id at every host. An unnamed literal stays one node per instance
# (Q1; design §3 Content).
{
  genDeliveryWith,
  scope,
  aspects,
  genMerge,
  term,
  ...
}:
let
  inherit (aspects) guard pred;
  t = genMerge.types;
  cnf.keySemantics.T.category = "class";
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
  src = n: "entity:${builtins.hashString "sha256" n}";
  project =
    values:
    (genDeliveryWith scope).project {
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
    } cnf values;
  try =
    v:
    let
      r = builtins.tryEval (builtins.deepSeq v v);
    in
    if r.success then r.value else "REFUSED";
  marksIn =
    m:
    if builtins.isAttrs m then
      (m.marks or [ ]) ++ builtins.concatMap marksIn (m.imports or [ ])
    else
      [ ];
  # What each host receives, and how many distinct ids its slots name.
  run =
    aspects': hosts:
    let
      p = project (ev [
        {
          aspects = aspects';
          inherit hosts;
        }
      ]);
    in
    try (
      builtins.mapAttrs (h: _: {
        marks = builtins.concatMap marksIn p.nodes.${h}.classes.T;
        # the ids of the content slots (an aspect's own slot is its facts or instance id)
        ids = builtins.filter (
          i: builtins.isString i && builtins.match ".*/includes/.*" i != null
        ) p.nodes.${h}.elementIds.T;
      }) hosts
    );
  g = body: guard (pred.has "host") body;
  arms = x: {
    withStatic =
      run
        {
          s.includes = [ x ];
          a = g { includes = [ x ]; };
        }
        {
          h.aspects = [
            "s"
            "a"
          ];
        };
    twoGuards =
      run
        {
          a = g { includes = [ x ]; };
          b = g { includes = [ x ]; };
        }
        {
          h.aspects = [
            "a"
            "b"
          ];
        };
    twoHosts = run { a = g { includes = [ x ]; }; } {
      h.aspects = [ "a" ];
      k.aspects = [ "a" ];
    };
  };
  tmux = {
    name = "tmux";
    T.marks = [ "tmux" ];
  };
  lit = {
    T.marks = [ "lit" ];
  };
  mk = m: {
    name = "tape";
    T.marks = [ m ];
  };
  named = arms tmux;
  unnamed = arms lit;
in
{
  # D1 (the premise, delivered). A host reaching a named value through a static taker and an instance,
  # or through two instances, receives it ONCE, under one id; two hosts reaching one guard name one id.
  # RED (gen-aspects fd07b3c): `withStatic` and `twoGuards` deliver `tmux` twice, under a class id and
  # an `aspect-instance:<iid>/includes/0` (or two of the latter); `twoHosts` names one id per instance.
  flake.tests.named-content-applied-bodies.test-a-named-value-in-applied-bodies-is-delivered-once = {
    expr = {
      withStatic = named.withStatic.h.marks;
      twoGuards = named.twoGuards.h.marks;
      oneIdPerHost = map (a: builtins.length named.${a}.h.ids) [
        "withStatic"
        "twoGuards"
      ];
      twoHostsOneId = named.twoHosts.h.ids == named.twoHosts.k.ids;
    };
    expected = {
      withStatic = [ "tmux" ];
      twoGuards = [ "tmux" ];
      oneIdPerHost = [
        1
        1
      ];
      twoHostsOneId = true;
    };
  };

  # D2. What stays apart. An unnamed literal is one node per instance (Q1), so a host reaching it
  # through two instances receives it twice and two hosts name two ids; a factory's two contents in two
  # guards are two classes, each delivered with its own content, and so are a static and an applied
  # sighting with different content. RED: none at base (these are the controls); gen-aspects mutant
  # rung-always-same merges the factory (`[ "f2" ]`); mutant applied-without-prior gives the applied
  # class the static class's id, so the host receives `[ "static" ]` alone.
  flake.tests.named-content-applied-bodies.test-unnamed-and-unequal-applied-content-stays-apart = {
    expr = {
      # a static and an applied sighting at one `name` position with different content
      mixed =
        (run
          {
            s.includes = [ (mk "static") ];
            a = g { includes = [ (mk "applied") ]; };
          }
          {
            h.aspects = [
              "s"
              "a"
            ];
          }
        ).h.marks;
      unnamed = unnamed.twoGuards.h.marks;
      unnamedTwoHosts = unnamed.twoHosts.h.ids == unnamed.twoHosts.k.ids;
      factory =
        (run
          {
            a = g { includes = [ (mk "f1") ]; };
            b = g { includes = [ (mk "f2") ]; };
          }
          {
            h.aspects = [
              "a"
              "b"
            ];
          }
        ).h.marks;
    };
    expected = {
      mixed = [
        "static"
        "applied"
      ];
      unnamed = [
        "lit"
        "lit"
      ];
      unnamedTwoHosts = false;
      factory = [
        "f1"
        "f2"
      ];
    };
  };

  # D3. A §4 row 4 pair (two distinct named values whose content contains a cycle) carried by one
  # host's CONTEXT value, minted through `instancesFor`'s context route, aborts only the reads whose
  # answer needs that comparison: every other host's projection reads. Arms: the pair on one host's
  # ancestor chain; one sighting at each of two hosts; an applied sighting against a static one (the
  # join); the pair at the key of `y`'s own sighting, which compares apart from both; `y`'s sighting
  # equal to one written inside the pair, at a key holding two classes; and, with no pair, another
  # host's `name` that is a missing attribute, at the top of its value and above a sighting equal to
  # `y`'s at a key holding two classes. RED the lift's applied content named by class id (v1): `y`'s
  # projection forces `x`'s classes and aborts; gen-aspects' least site under the enclosing class (C3's
  # static form): `belowSeveralClasses` aborts; every applied `name` forced to key it: `nameElsewhere`
  # aborts; an applied site that asks whether it has a named ancestor: `nameAboveElsewhere` aborts.
  flake.tests.named-content-applied-bodies.test-a-row-4-pair-in-one-host-leaves-the-others =
    let
      cyc =
        _:
        let
          m = {
            self = m;
            v = 1;
          };
        in
        m;
      mkc = inc: {
        name = "c";
        T.marks = [ "c" ];
        meta = cyc 0;
        includes = inc;
      };
      mke = _: {
        name = "e";
        T.marks = [ "e" ];
        extra = cyc 0;
      };
      mkq = c: {
        name = "q";
        T.marks = [ "q" ];
        meta = if c then cyc 0 else 1;
      };
      tmux = {
        name = "tmux";
        T.marks = [ "tmux" ];
      };
      tf = m: {
        name = "tf";
        T.marks = [ m ];
      };
      projY =
        statics: vals:
        let
          values = ev [
            {
              aspects = {
                g = guard (pred.has "host") { includes = [ (term.readCtx "host" [ ]) ]; };
              }
              // statics;
              hosts = builtins.mapAttrs (_: _: { aspects = [ "g" ]; }) vals;
            }
          ];
          p = (genDeliveryWith scope).project {
            instances =
              aspects.instancesFor cnf values.aspects
                {
                  suppliers = builtins.listToAttrs (
                    map (h: {
                      name = src h;
                      value.host = vals.${h};
                    }) (builtins.attrNames vals)
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
          } cnf values;
        in
        builtins.concatMap marksIn p.nodes.y.classes.T;
    in
    {
      expr = {
        ancestorChain = projY { } {
          x = mkc [ (mkc [ ]) ];
          y = tmux;
        };
        twoHosts = projY { } {
          x = mkc [ ];
          z = mkc [ ];
          y = tmux;
        };
        join = projY { st.includes = [ (mke 0) ]; } {
          x = mke 1;
          y = tmux;
        };
        sameKey = projY { } {
          x = mkq true;
          z = mkq true;
          y = mkq false;
        };
        belowSeveralClasses = projY { } {
          x = mkc [ (mkc [ (tf "a") ]) ];
          y = tf "a";
          z = tf "b";
        };
        nameElsewhere = projY { } {
          x = {
            name = ({ }).nope;
            T.marks = [ "x" ];
          };
          y = tmux;
        };
        nameAboveElsewhere = projY { } {
          x = {
            name = ({ }).nope;
            T.marks = [ "x" ];
            includes = [ (tf "a") ];
          };
          y = tf "a";
          z = tf "b";
        };
      };
      expected = {
        ancestorChain = [ "tmux" ];
        twoHosts = [ "tmux" ];
        join = [ "tmux" ];
        sameKey = [ "q" ];
        belowSeveralClasses = [ "a" ];
        nameElsewhere = [ "tmux" ];
        nameAboveElsewhere = [ "a" ];
      };
    };

  # D4, a DECLARED RESIDUE (ADR-0025 item 1; ADR-0034's quotient paragraph, its third declared
  # exception), retiring at den-hoag-gkrtw. A named class collapses `==`-equal sightings, and Nix `==`
  # ignores string context, so two sightings that differ only in context are one node that keeps ONE
  # sighting's context, not the union: the static node's where the class joined one, else the
  # occurrence the receiver keeps (the first it reaches). `f` with a context-carrying string in guard `g` and a context-free
  # copy in `a`: `x` reaches `g` alone, `y` both, `z` (static arm) `a` alone. This cell pins the
  # residue as it stands; gkrtw's landing (store dependencies as graph edges) flips it. RED (gen-aspects
  # fd07b3c, one node per instance): `joined.x` and `appliedOnly.x` carry context under their own ids.
  flake.tests.named-content-applied-bodies.test-a-collapsed-class-keeps-one-sightings-context =
    let
      drv = derivation {
        name = "named-content-ctx";
        builder = "/bin/sh";
        system = "x86_64-linux";
      };
      withCtx = "${drv}";
      noCtx = builtins.unsafeDiscardStringContext withCtx;
      mk = s: {
        name = "f";
        T.marks = [ s ];
      };
      read =
        a: hosts:
        let
          p = project (ev [
            {
              aspects = a;
              hosts = builtins.mapAttrs (_: as: { aspects = as; }) hosts;
            }
          ]);
          ctxOf = h: map builtins.hasContext (builtins.concatMap marksIn p.nodes.${h}.classes.T);
          idsOf =
            h:
            builtins.filter (
              i: builtins.isString i && builtins.match ".*/includes/.*" i != null
            ) p.nodes.${h}.elementIds.T;
        in
        builtins.mapAttrs (h: _: ctxOf h) hosts // { oneId = idsOf "x" == idsOf "y"; };
    in
    {
      expr = {
        controls = [
          ((mk noCtx) == (mk withCtx))
          (builtins.hasContext withCtx)
          (builtins.hasContext noCtx)
        ];
        joined =
          read
            {
              a.includes = [ (mk noCtx) ];
              g = g { includes = [ (mk withCtx) ]; };
            }
            {
              x = [ "g" ];
              y = [
                "a"
                "g"
              ];
              z = [ "a" ];
            };
        appliedOnly =
          read
            {
              a = g { includes = [ (mk noCtx) ]; };
              g = g { includes = [ (mk withCtx) ]; };
            }
            {
              x = [ "g" ];
              y = [
                "a"
                "g"
              ];
            };
      };
      expected = {
        controls = [
          true
          true
          false
        ];
        joined = {
          x = [ false ];
          y = [ false ];
          z = [ false ];
          oneId = true;
        };
        appliedOnly = {
          x = [ true ];
          y = [ false ];
          oneId = true;
        };
      };
    };

  # D5. A value another evaluation stamped is a sighting of THIS relation, sited at its root path. `p`'s
  # two contents, each stamped by its own evaluation at one declaration address (`st2`'s include 0), reach
  # host `z` through the context route beside a static taker of a third: three classes at one key, so
  # each id carries its least site. The stamp's address is foreign to this tree and the same for both,
  # so a site read off the stamp names the two applied classes alike and `z` keeps one of them. RED an
  # applied site that keeps the stamp's address (gen-aspects mutants enclsite, stampsite): `z` receives
  # `[ "s" "a" ]` under two ids.
  flake.tests.named-content-applied-bodies.test-two-stamps-at-one-foreign-address-stay-two-classes =
    let
      mkp = m: {
        name = "p";
        T.marks = [ m ];
      };
      stamped = m: builtins.head (ev [ { aspects.st2.includes = [ (mkp m) ]; } ]).aspects.st2.includes;
      vals = {
        x = stamped "a";
        y = stamped "b";
        z.includes = [
          (stamped "a")
          (stamped "b")
        ];
      };
      members = {
        x = [ "g" ];
        y = [ "g" ];
        z = [
          "g"
          "st"
        ];
      };
      values = ev [
        {
          aspects.st.includes = [ (mkp "s") ];
          aspects.g = guard (pred.has "host") { includes = [ (term.readCtx "host" [ ]) ]; };
          hosts = builtins.mapAttrs (_: ms: { aspects = ms; }) members;
        }
      ];
      p = (genDeliveryWith scope).project {
        instances =
          aspects.instancesFor cnf values.aspects
            {
              suppliers = builtins.listToAttrs (
                map (h: {
                  name = src h;
                  value.host = vals.${h};
                }) (builtins.attrNames vals)
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
      } cnf values;
      ids = builtins.filter (
        i: builtins.isString i && builtins.match "@/includes/p@.*" i != null
      ) p.nodes.z.elementIds.T;
    in
    {
      expr = try {
        marks = builtins.concatMap marksIn p.nodes.z.classes.T;
        ids = builtins.length (
          builtins.attrNames (
            builtins.listToAttrs (
              map (n: {
                name = n;
                value = null;
              }) ids
            )
          )
        );
      };
      expected = {
        marks = [
          "s"
          "a"
          "b"
        ];
        ids = 3;
      };
    };
  # D6. The rung's partition reads a value only where another value at its key agrees with it on
  # everything read before, as `==` does, so a leaf no comparison reaches is never read. One factory
  # (one `name` position) makes `x`'s value, whose `T` holds an extra attribute with an uncatchable
  # leaf, and `y`'s; `==` between them stops at `T`'s attribute names. RED a partition keyed by a
  # bounded walk of every value (a fingerprint): `y`'s projection aborts when `x` sorts first.
  flake.tests.named-content-applied-bodies.test-a-leaf-no-comparison-reaches-is-never-read =
    let
      f = m: extra: {
        name = "t";
        T = {
          marks = [ m ];
        }
        // extra;
      };
      readY =
        first:
        let
          bad = g { includes = [ (f "a" { deep.zz = ({ }).nope; }) ]; };
          good = g { includes = [ (f "b" { }) ]; };
          p = project (ev [
            {
              aspects =
                if first == "x" then
                  {
                    a1 = bad;
                    a2 = good;
                  }
                else
                  {
                    a1 = good;
                    a2 = bad;
                  };
              hosts = {
                x.aspects = [ (if first == "x" then "a1" else "a2") ];
                y.aspects = [ (if first == "x" then "a2" else "a1") ];
              };
            }
          ]);
        in
        builtins.concatMap marksIn p.nodes.y.classes.T;
    in
    {
      expr = {
        xFirst = readY "x";
        yFirst = readY "y";
      };
      expected = {
        xFirst = [ "b" ];
        yFirst = [ "b" ];
      };
    };

  # D7. A value's id is read only where it is needed (owner 2026-10-31, P1-c: a LAZY ID): a host holding
  # one applied named value alone at its §2 key reads its content without its class id, so a leaf no
  # comparison reaches, which the id's digest would read, is never read by projecting the host's own
  # content, nested content included, as at main. One factory makes `x`'s value (`T` holding an
  # uncatchable leaf) and `y`'s. RED the id read by every projection (sfkyy-a4): `x`'s projection aborts.
  flake.tests.named-content-applied-bodies.test-a-value-alone-at-its-key-is-projected-without-its-id =
    let
      f =
        nested: m: extra:
        {
          name = "t";
          T = {
            marks = [ m ];
          }
          // extra;
        }
        // (if nested then { includes = [ { T.marks = [ "inner-${m}" ]; } ]; } else { });
      readX =
        nested:
        let
          p = project (ev [
            {
              aspects = {
                a1 = g { includes = [ (f nested "a" { deep.zz = ({ }).nope; }) ]; };
                a2 = g { includes = [ (f nested "b" { }) ]; };
              };
              hosts = {
                x.aspects = [ "a1" ];
                y.aspects = [ "a2" ];
              };
            }
          ]);
        in
        builtins.concatMap marksIn p.nodes.x.classes.T;
    in
    {
      expr = {
        flat = readX false;
        nested = readX true;
      };
      expected = {
        flat = [ "a" ];
        nested = [
          "a"
          "inner-a"
        ];
      };
    };
}
