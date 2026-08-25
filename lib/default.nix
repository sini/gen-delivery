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
# Only plain data crosses a gen↔gen boundary. This library takes `algebra` and `aspects` as VALUES
# and constructs inside the consumer's own evaluation; it re-exports neither, and in particular it
# republishes no gen-aspects accessor and no algebra constructor under a name of its own. The
# key-category DECLARATION reaches the predicate the same way — as an argument, never as a
# co-resident — which is why this library can read a declaration gen-aspects owns without
# gen-aspects acquiring a delivery-shaped role over the facts it publishes.
#
# ── AND THE ORDERED FOLD IS NOT WRITTEN HERE ──
# The contribution merge is `algebra.record.foldLayers`: an ordered layer list, least-specific
# first, last wins, no strength lattice, an unknown per-field strategy refused by name. That is
# already the compliant shape for an ordered fold, and it is already built. What this surface writes
# is the LAYER DECLARATION — which layers exist and in what order — and that declaration is its own
# readable artefact rather than a parameter of somebody else's fold. No `strategies` are passed: the
# default is `replace`, which is measured equal to the positional `//` chain this merge has always
# been, so the per-field knob is available and unexercised here.
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
{ algebra, aspects }:
let
  # ── THE DECLARED CONTRIBUTION ORDER ──
  # An ordered list of NAMED contribution layers, least-specific first, folded in declared order.
  # The order is a PARAMETER of the realization and a declaration with a default value — never an
  # implicit one, and never derived from what kind of thing each layer is. A derivation over a
  # kind hierarchy would re-import the topology an ordered fold exists to keep out.
  #
  #   projection  the projection's own binding for the node — `{ node = <resolved instance>; }`.
  #   global      the caller's attrset, applied to every node.
  #   refinement  the caller's per-node entry, `{ <node> = <attrset>; }`.
  #
  # THE THREE ARE SEPARATE INPUTS, and that is a fix rather than a shape. They used to be two: one
  # attrset carrying both the global layer AND the per-node refinements under node-named keys,
  # disambiguated by a runtime `isAttrs` guess. The consequence was admitted in the contract's own
  # header — a node-named refinement key also rode into every node's merged bindings as a literal
  # binding, surprising whenever a formal happened to share a node name. Named layers separate the
  # two namespaces by construction, and an explicit layer list cannot even be written while one
  # layer is nested inside another.
  defaultLayerOrder = [
    "projection"
    "global"
    "refinement"
  ];

  # ── THE REALIZATION PREDICATE ──
  # ADR-0028's Rider: a delivery class realizes only on DECLARED CONTENT, never on structural
  # shape. A key of a flat-registry aspect entry is a delivery class iff BOTH:
  #
  #   1. it is DECLARED `category = "class"`, read through gen-aspects' single classification
  #      surface and never re-derived here; and
  #   2. it CARRIES CONTENT at this entry.
  #
  # SHAPE IS NEVER CONSULTED FOR CLASSIFICATION, and that is the whole of the fix. The predicate
  # this replaces asked whether the value was an attrset carrying an `imports` list, which is a
  # shape test wearing content's clothes. It read clean on the contentless arm only because
  # gen-aspects renders a declared-but-unset class as `null` rather than fabricating an empty
  # deferredModule — a representation choice in ANOTHER library, so the Rider was discharged by
  # coincidence and guarded by a tripwire rather than held by construction. And on a second arm it
  # was simply wrong: a key declared `category = "channel"` rides its value VERBATIM, so a channel
  # carrying a module — the cross-framework exchange payload the category exists for — was
  # projected as a delivery class and had its terminal called. A facet declared with a permissive
  # option type does the same. Limb 1 closes both; limb 2 closes the contentless arm independently
  # of how gen-aspects chooses to represent absence.
  deliveryClassesOf =
    cnf: entry:
    builtins.filter (k: aspects.keyCategory cnf k == "class" && hasContent entry.${k}) (
      builtins.attrNames entry
    );

  # LIMB 2. `null` is gen-aspects' representable absence for a declared-but-unset class. The
  # attrset arm is the FABRICATED EMPTY deferredModule — a module carrying nothing, which is the
  # state the Rider's hazard turns on and the one the surrounding suite could never exhibit. The
  # test is on the whole key set, not on `imports` alone, so a module that carries a definition
  # beside an empty `imports` still counts as content.
  hasContent =
    v: v != null && !(builtins.isAttrs v && builtins.attrNames v == [ "imports" ] && v.imports == [ ]);

  # THE DECLARATION INPUT'S ABSENCE IS A REFUSAL, and the KEY-level absence is not — the two go
  # opposite ways and collapsing them is the harmful reading. Constructed with no category source
  # this surface has nothing to read a declaration from, and the only thing left to fall back on is
  # the shape test being removed, so it refuses by name. A KEY whose category is `null` is the
  # ordinary, ubiquitous state of a nested aspect — gen-aspects documents `null` as its answer for
  # an unregistered key and a consumer's typo gate is built on exactly that — so an undeclared key
  # is simply not a delivery class and nothing throws. The refusal that IS owed for an unrecognised
  # key already exists upstream, at schema construction, and duplicating it here would throw on
  # every nested aspect in the corpus.
  requireCnf =
    cnf:
    if cnf != null then
      cnf
    else
      throw "gen-delivery: project: no category source — `cnf` is required and has no default. The realization predicate reads the key-category declaration; with none it could only fall back to a structural shape test.";

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
    cnf: selectHosts: values: registry:
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
          classNames = dedup (builtins.concatMap (a: deliveryClassesOf cnf registry.${a}) memberAspects);
          collectClass =
            class:
            builtins.concatMap (
              a:
              let
                entry = registry.${a};
              in
              if builtins.elem class (deliveryClassesOf cnf entry) then [ entry.${class} ] else [ ]
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
      # THE DECLARATION INPUT — the caller's own `mkAspectSchema` argument, arriving BESIDE the
      # values rather than through them. `null` is not a default: it is the absent state, and
      # `requireCnf` refuses it by name. Absence here is a decision, and a defaulted category
      # source would silently degrade the predicate to the shape test being removed.
      cnf ? null,
      # `values → { <node> = instance; }` — names which resolved attrset holds the node instances.
      selectHosts ? (v: v.hosts or { }),
    }:
    let
      # Forced by the `seq` below rather than only where the predicate reads it. A registry with no
      # member aspects never reaches the predicate at all, so a lazy refusal would let the surface
      # be CONSTRUCTED with no category source and stay silent until some later fixture happened to
      # have content — which is a refusal that fires on the size of the input.
      declaration = requireCnf cnf;
      registry = if values ? aspects then aspects.flatten values.aspects else { };
    in
    builtins.seq declaration {
      # The FLAT aspect registry (keyed by aspect path): each entry carries its per-class
      # deferredModule fields. The deferredModules are inspectable but unforced, so class bodies
      # cross into a target's evaluation unevaluated. Absent an `aspects` surface, this is empty.
      aspects = registry;

      # The per-node build projection — a node-keyed reshape of the flat registry, driven by each
      # node's `aspects` membership. This is what the terminal builds from.
      nodes = projectNodes declaration selectHosts values registry;
    };

  # `realize` — the terminal registry fold. PURE (builtins only, no nixpkgs). It turns a `project`
  # result plus a per-class terminal into class-major artifacts:
  #
  #     realize { projected; terminals; bindings ? {}; refinements ? {}; layerOrder ? …;
  #               extraModules ? {}; } -> { <class>.<node> = artifact; }
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
  #   bindings     the contribution layers folded in the DECLARED order (`layerOrder`). There is no
  #                separate `node` field — `bindings.node` IS the resolved instance, contributed by
  #                the projection layer.
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
      # THE GLOBAL contribution layer: one attrset applied to every node. It holds bindings and
      # nothing else — a key here named after a node is a binding named after a node, not that
      # node's refinement.
      bindings ? { },
      # THE PER-NODE contribution layer: `{ <node> = <attrset>; }`. A separate input from the
      # global layer, which is what keeps the two namespaces apart by construction.
      refinements ? { },
      # THE DECLARED ORDER over those layers, least-specific first. A default value, readable and
      # overridable; never an implicit order, and never derived from what kind of thing a layer is.
      layerOrder ? defaultLayerOrder,
      # `{ <node> = [ module ]; }` — per-node extras handed to the terminal (`[]` when absent).
      extraModules ? { },
    }:
    let
      nodes = projected.nodes;

      # The class-major fold. `realized` is self-referential: a node's `extent` is
      # THE DECLARED ORDER IS TOTAL OVER THE LAYERS, IN BOTH DIRECTIONS. An omitted layer is a
      # DELETED CONTRIBUTION, not a shorter list: drop `projection` and `bindings.node` — which this
      # contract documents as always present — silently vanishes, and the terminal that reads it
      # fails deep inside the target, far from the edit. ADR-0029's precondition is a DECLARED TOTAL
      # order, and one direction guarded is not that. Checked once per call and forced at the root,
      # for the same reason the category source is: a realization with no nodes never reaches the
      # per-node fold, so a lazy check would fire on the SIZE of the input.
      _layerOrderCheck =
        let
          sep = builtins.concatStringsSep ", ";
          missing = builtins.filter (l: !(builtins.elem l layerOrder)) defaultLayerOrder;
          unknown = builtins.filter (l: !(builtins.elem l defaultLayerOrder)) layerOrder;
        in
        if missing != [ ] then
          throw "gen-delivery: realize: layerOrder omits contribution layer(s) ${sep missing} — the order is DECLARED and TOTAL over ${sep defaultLayerOrder}, so an omitted layer deletes its contribution"
        else if unknown != [ ] then
          throw "gen-delivery: realize: layerOrder names ${sep unknown}, which is not a contribution layer (declared: ${sep defaultLayerOrder})"
        else
          null;

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
                      contributions = {
                        projection = nc.bindings;
                        global = bindings;
                        refinement = refinements.${nodeName} or { };
                      };
                      mergedBindings = algebra.record.foldLayers {
                        layers = map (l: contributions.${l}) layerOrder;
                      };
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
    builtins.seq _layerOrderCheck realized;
in
{
  inherit project realize;

  # The layer declaration, published. An order that ships as a default is only a declaration if a
  # consumer can read it; one that can only be overridden is an implicit order with a hatch.
  inherit defaultLayerOrder;
}
