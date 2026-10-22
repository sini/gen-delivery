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
  # host's `name` that is a missing attribute. RED the lift's applied content named by class id (v1):
  # `y`'s projection forces `x`'s classes and aborts; gen-aspects' least site under the enclosing class
  # (C3's static form): `belowSeveralClasses` aborts; every applied `name` forced to key it:
  # `nameElsewhere` aborts.
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
      };
      expected = {
        ancestorChain = [ "tmux" ];
        twoHosts = [ "tmux" ];
        join = [ "tmux" ];
        sameKey = [ "q" ];
        belowSeveralClasses = [ "a" ];
        nameElsewhere = [ "tmux" ];
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
}
