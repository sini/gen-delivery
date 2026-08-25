# gen-delivery — THE DELIVERY-CLASS REALIZATION SURFACE.
#
# ADR-0028 rules a DELIVERY CLASS: content declared on an aspect, collected per node, and handed to
# a target-owned terminal that turns it into an artifact. This library is the surface that does
# that. It is ONE construct in two halves — the PROJECTION that discovers which keys are delivery
# classes and reshapes the flat aspect registry per node, and the FOLD that calls each class's
# terminal — and they are one because the realization predicate lives in the first half while the
# fold that trusts it lives in the second. Splitting them puts a predicate in one library and its
# only consumer in another.
#
# ── THE SUBSTRATE ARRIVES INJECTED, WHICH IS THE BOUNDARY RULE AND NOT A CONVENIENCE ──
# Only plain data crosses a gen↔gen boundary. This library takes `aspects` as a VALUE and constructs
# inside the consumer's own evaluation; it re-exports it nowhere, and in particular it republishes
# no gen-aspects accessor under a name of its own. The key-category DECLARATION reaches the
# predicate the same way — as an argument, never as a co-resident — which is why this library can
# read a declaration gen-aspects owns without gen-aspects acquiring a delivery-shaped role over the
# facts it publishes.
#
# ── WHAT IS ABOVE THE STACK RATHER THAN A LAYER OF IT ──
# Delivery targets and terminals are framework notions: a configuration framework assembles with
# this surface, and no substrate vocabulary is defined in its terms. That is the `framework` stratum
# on the bucket's own words, and it turns on what the surface DOES — realize delivery targets by
# invoking a caller-supplied terminal — rather than on any name it carries.
#
# ── THE CONTRACT'S NAMES, EACH RESOLVED RATHER THAN PREFERRED ──
# Framework naming never becomes substrate vocabulary, so the three names the dissolving library
# carried are resolved here and not relocated:
#
#   node        was `host`. `node` is ruled substrate vocabulary — a node is a position with
#               attributes and incident labelled edges, of which a registry instance is a VIEW —
#               and the resolved instance under `bindings` is exactly that. `host` is attested in
#               the corpus only in the unrelated DSL-embedding sense ("host language"), so its
#               presence there is not support.
#   extent      was `nodes`, which collided with the ruled term above while meaning something
#               else: the field holds realized ARTIFACTS keyed by node, not nodes. The extent of a
#               predicate is the set of objects of the universe for which it holds (Gelfond &
#               Lifschitz 1988, stable model semantics), and realization is a predicate, so the set
#               of nodes it holds for is that predicate's extent. ★ PRECISELY: the field is NOT the
#               extent — it is an attrset whose SPINE is the extent. Naming a container after its
#               index set is the mirror image of the error being corrected.
#   passthrough was `osConfig`, and it takes no substrate term because none should exist for it.
#               `osConfig` is a nixpkgs/home-manager identifier: framework naming is surface
#               vocabulary at the surface and never substrate vocabulary in a contract, so the fix
#               is to stop pinning one framework's field name here. The contract carries a single
#               TARGET-OWNED passthrough channel, opaque to this surface, of which `osConfig` is one
#               framework's instance named by the consumer. The surface never reads inside it. The
#               name is minted from the ruling's own words and carries no theory citation.
#
# `modules`, `bindings` and `name` are out of scope for the rename: the first is the module
# system's own vocabulary, the second is already the substrate's relation vocabulary, and the third
# is the member's key rather than a framework term.
{ aspects }:
let
  # The class fields of a flat-registry aspect entry: keys whose value is a deferredModule (an
  # attrset carrying an `imports` LIST). STRUCTURAL — and structural is the defect. A class DECLARED
  # but never given content reads `null` today (gen-aspects represents absence rather than
  # fabricating an empty deferredModule), so `isAttrs` below excludes it and the projection is
  # content-driven BY COINCIDENCE: should the class option ever read as `{ imports = [ ]; }`, this
  # filter admits it and the terminal is called on structural shape, which ADR-0028's Rider forbids.
  # A key declared as a CHANNEL whose value carries an `imports` list is admitted here too, which no
  # representation choice upstream can fix. Both arms close when the predicate reads the DECLARATION.
  classFieldsOf =
    entry:
    builtins.filter (
      k:
      let
        v = entry.${k};
      in
      builtins.isAttrs v && v ? imports && builtins.isList v.imports
    ) (builtins.attrNames entry);

  # `dedup` — order-preserving unique over a string list, builtins-only (listToAttrs collapses dups).
  dedup =
    xs:
    builtins.attrNames (
      builtins.listToAttrs (
        map (x: {
          name = x;
          value = null;
        }) xs
      )
    );

  # `projectNodes` — the node-keyed reshape of the FLAT aspect registry. For each node instance,
  # gather the deferredModules of each class across the aspects the node declares membership in
  # (`node.aspects`). `selectHosts` names WHICH resolved attrset holds the node instances — a nested
  # registry layout (`fleet.hosts`) would otherwise project empty under a hardcoded `values.hosts`
  # read. It keeps its published name: the override merge law's REPLACE clause names this formal,
  # and that law does not move with this surface. Yields
  #   { <node> = { bindings = { node = <resolved instance>; }; classes = { <class> = [ <deferredModule> ]; }; }; }
  # PURE — no nixpkgs; the deferredModules stay unforced (opaque) until the terminal imports them.
  projectNodes =
    selectHosts: values: registry:
    let
      nodes = selectHosts values;
      # `selectHosts` is caller-supplied; a non-attrset result would die inside `mapAttrs` as an
      # anonymous "expected a set" — name the surface, the arg, and the contract instead.
      _nodesCheck =
        if builtins.isAttrs nodes then
          null
        else
          throw "gen-delivery: project: selectHosts must return an attrset of node instances ({ <node> = <instance>; }), got ${builtins.typeOf nodes}";
    in
    builtins.seq _nodesCheck (
      builtins.mapAttrs (
        _nodeName: inst:
        let
          memberAspects = builtins.filter (a: registry ? ${a}) (inst.aspects or [ ]);
          classNames = dedup (builtins.concatMap (a: classFieldsOf registry.${a}) memberAspects);
          collectClass =
            class:
            builtins.concatMap (
              a:
              let
                entry = registry.${a};
              in
              if builtins.elem class (classFieldsOf entry) then [ entry.${class} ] else [ ]
            ) memberAspects;
        in
        {
          bindings = {
            node = inst;
          };
          classes = builtins.listToAttrs (
            map (c: {
              name = c;
              value = collectClass c;
            }) classNames
          );
        }
      ) nodes
    );

  # `project` — the flat aspect registry plus the per-node build projection. Both keys were
  # published by the dissolving library's compose result; they are this surface's own now.
  project =
    {
      # The resolved config VALUES of the caller's own evaluation.
      values,
      # `values → { <node> = instance; }` — names which resolved attrset holds the node instances.
      selectHosts ? (v: v.hosts or { }),
    }:
    let
      registry = if values ? aspects then aspects.flatten values.aspects else { };
    in
    {
      # The FLAT aspect registry (keyed by aspect path): each entry carries its per-class
      # deferredModule fields. The deferredModules are inspectable but unforced, so class bodies
      # cross into a target's evaluation unevaluated. Absent an `aspects` surface, this is empty.
      aspects = registry;

      # The per-node build projection — a node-keyed reshape of the flat registry, driven by each
      # node's `aspects` membership. This is what the terminal builds from.
      nodes = projectNodes selectHosts values registry;
    };

  # `realize` — the terminal registry fold. PURE (builtins only, no nixpkgs). It turns a `project`
  # result plus a per-class terminal into class-major artifacts:
  #
  #     realize { projected; terminals; bindings ? {}; extraModules ? {}; } -> { <class>.<node> = artifact; }
  #
  # For each class that has a terminal, every node whose projection carries a NON-EMPTY module list
  # for that class is realized by calling the terminal with the pinned contract (below). A node with
  # no content for a class does not appear under it — the output is class-major and content-driven.
  # Each consumed `projected.nodes.<name>` entry MUST carry `bindings`, so the bare `nc.bindings`
  # read below fails loud on a malformed projection rather than papering over it.
  #
  # Terminal contract (every field pinned):
  #   name         the node's registry key (string).
  #   modules      `projected.nodes.<name>.classes.<class>` — this class's deferredModule list.
  #                Opaque and unforced; the terminal decides whether/when to evaluate it.
  #   bindings     the merged binding set, most specific wins: the projection's
  #                `{ node = <instance> }` < global `bindings` < per-node `bindings.<name>`. There
  #                is no separate `node` field — `bindings.node` IS the resolved instance.
  #   extent       the `realized.<class>` set itself — a lazy cross-node accessor for THIS class,
  #                and for this class ONLY: a terminal never receives a peer class's set. Its SPINE
  #                is the class's node keys, so reading the keys forces no peer artifact.
  #   extraModules the per-node extras for this node (`[]` when absent).
  #   passthrough  the TARGET-OWNED channel, present IFF the node's projection entry carries one.
  #                Opaque: this surface never reads inside it, and the keys in it are the
  #                consumer's own (`osConfig` is one framework's instance of one).
  realize =
    {
      # A `project` result; only `.nodes` (the per-node build projection) is consumed.
      projected,
      # `{ <class> = terminal; }` — which classes to realize, and how. The output keys are exactly
      # these class names.
      terminals,
      # The extra-bindings hook: a global attrset applied to every node, optionally carrying
      # per-node refinements under `<node>` keys (`bindings.<node>` wins over the global layer). The
      # global layer splats WHOLESALE (`nc.bindings // bindings // perNode`), so any node-named
      # refinement key also rides into every node's merged bindings as a literal binding — harmless,
      # but surprising if a formal happens to share a node name.
      bindings ? { },
      # `{ <node> = [ module ]; }` — per-node extras handed to the terminal (`[]` when absent).
      extraModules ? { },
    }:
    let
      nodes = projected.nodes;

      # The class-major fold. `realized` is self-referential: a node's `extent` is
      # `realized.<class>`, the same set being built — lazy, so forcing one node's artifact never
      # forces a peer's (the spine is only the class's node keys, populated by `listToAttrs` names).
      realized = builtins.mapAttrs (
        className: terminal:
        builtins.listToAttrs (
          builtins.concatMap (
            nodeName:
            let
              nc = nodes.${nodeName};
              classModules = nc.classes.${className} or [ ];
            in
            if classModules == [ ] then
              [ ]
            else
              [
                {
                  name = nodeName;
                  value =
                    let
                      # The per-node refinement layer, applied only when `bindings.<name>` is an
                      # attrset (a bare global value under a node-named key is not a refinement).
                      perNode = if builtins.isAttrs (bindings.${nodeName} or null) then bindings.${nodeName} else { };
                      mergedBindings = nc.bindings // bindings // perNode;
                    in
                    terminal (
                      {
                        name = nodeName;
                        modules = classModules;
                        bindings = mergedBindings;
                        extent = realized.${className};
                        extraModules = extraModules.${nodeName} or [ ];
                      }
                      # The carriage side of the passthrough, renamed. The weld that once tied this
                      # emitted key to the entry's field name is already split, so the target-facing
                      # key a class module reads is derived from nothing here and stays whatever the
                      # consumer put INSIDE the channel.
                      // (if nc ? passthrough then { passthrough = nc.passthrough; } else { })
                    );
                }
              ]
          ) (builtins.attrNames nodes)
        )
      ) terminals;
    in
    realized;
in
{
  inherit project realize;
}
