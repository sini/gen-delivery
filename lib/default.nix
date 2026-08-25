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
# republishes no gen-aspects accessor under a name of its own. The key-category DECLARATION reaches
# the predicate the same way — as an argument, never as a co-resident — which is why this library
# can read a declaration gen-aspects owns without gen-aspects acquiring a delivery-shaped role over
# the facts it publishes.
#
# ── WHAT IS ABOVE THE STACK RATHER THAN A LAYER OF IT ──
# Delivery targets and terminals are framework notions: a configuration framework assembles with
# this surface, and no substrate vocabulary is defined in its terms. That is the `framework`
# stratum on the bucket's own words, and it turns on what the surface DOES — realize delivery
# targets by invoking a caller-supplied terminal — rather than on any name it carries.
#
# ── RELOCATION NOTE ──
# The content is the gen-flake dissolution's unit 2 (ADR-0031 F2): the whole of `lib/realize.nix`
# plus six constructs from `lib/compose.nix` — the class-discovery rule, the order-preserving
# `dedup` it uses, the per-node reshape, the `selectHosts` formal, the flat-registry binding, and
# the two projected keys. This commit relocates them VERBATIM, welds and structural predicate
# intact, so that the fixes that follow are each a measurable step rather than one fused change.
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

  # `projectHosts` — the host-keyed reshape of the FLAT aspect registry. For each host instance,
  # gather the deferredModules of each class across the aspects the host declares membership in
  # (`host.aspects`). `selectHosts` names WHICH resolved attrset holds the host instances — a nested
  # registry layout (`fleet.hosts`) would otherwise project empty under a hardcoded `values.hosts`
  # read. Yields
  #   { <host> = { bindings = { host = <resolved instance>; }; classes = { <class> = [ <deferredModule> ]; }; }; }
  # PURE — no nixpkgs; the deferredModules stay unforced (opaque) until the terminal imports them.
  projectHosts =
    selectHosts: values: registry:
    let
      hosts = selectHosts values;
      # `selectHosts` is caller-supplied; a non-attrset result would die inside `mapAttrs` as an
      # anonymous "expected a set" — name the surface, the arg, and the contract instead.
      _hostsCheck =
        if builtins.isAttrs hosts then
          null
        else
          throw "gen-delivery: project: selectHosts must return an attrset of host instances ({ <host> = <instance>; }), got ${builtins.typeOf hosts}";
    in
    builtins.seq _hostsCheck (
      builtins.mapAttrs (
        _hostName: inst:
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
            host = inst;
          };
          classes = builtins.listToAttrs (
            map (c: {
              name = c;
              value = collectClass c;
            }) classNames
          );
        }
      ) hosts
    );

  # `project` — the flat aspect registry plus the per-host build projection. Both keys were
  # published by the dissolving library's compose result; they are this surface's own now.
  project =
    {
      # The resolved config VALUES of the caller's own evaluation.
      values,
      # `values → { <host> = instance; }` — names which resolved attrset holds the host instances.
      # Kept under its published name: the override merge law names this formal by name, and the
      # law does not move with this unit.
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

      # The per-host build projection — a host-keyed reshape of the flat registry, driven by each
      # host's `aspects` membership. This is what the terminal builds from.
      hosts = projectHosts selectHosts values registry;
    };

  # `realize` — the terminal registry fold. PURE (builtins only, no nixpkgs). It turns a `project`
  # result plus a per-class terminal into class-major artifacts:
  #
  #     realize { projected; terminals; bindings ? {}; extraModules ? {}; } -> { <class>.<host> = artifact; }
  #
  # For each class that has a terminal, every host whose projection carries a NON-EMPTY module list
  # for that class is realized by calling the terminal with the pinned contract (below). A host with
  # no content for a class does not appear under it — the output is class-major and content-driven.
  # Each consumed `projected.hosts.<name>` entry MUST carry `bindings`, so the bare `hc.bindings`
  # read below fails loud on a malformed projection rather than papering over it.
  #
  # Terminal contract (every field pinned):
  #   name         the host's registry key (string).
  #   modules      `projected.hosts.<name>.classes.<class>` — this class's deferredModule list.
  #                Opaque and unforced; the terminal decides whether/when to evaluate it.
  #   bindings     the merged binding set, most specific wins: the projection's
  #                `{ host = <instance> }` < global `bindings` < per-host `bindings.<name>`. There
  #                is no separate `host` field — `bindings.host` IS the resolved instance.
  #   nodes        the `realized.<class>` set itself — a lazy cross-host accessor for THIS class.
  #                Its spine is the class's host keys, so reading the keys forces no peer artifact.
  #   extraModules the per-host extras for this host (`[]` when absent).
  #   osConfig     present IFF the host's projection entry carries one (host-owned user/home
  #                content); passed through verbatim.
  realize =
    {
      # A `project` result; only `.hosts` (the per-host build projection) is consumed.
      projected,
      # `{ <class> = terminal; }` — which classes to realize, and how. The output keys are exactly
      # these class names.
      terminals,
      # The extra-bindings hook: a global attrset applied to every host, optionally carrying per-host
      # refinements under `<host>` keys (`bindings.<host>` wins over the global layer). The global
      # layer splats WHOLESALE (`hc.bindings // bindings // perHost`), so any host-named refinement
      # key also rides into every host's merged bindings as a literal binding — harmless, but
      # surprising if a formal happens to share a host name.
      bindings ? { },
      # `{ <host> = [ module ]; }` — per-host extras handed to the terminal (`[]` when absent).
      extraModules ? { },
    }:
    let
      hosts = projected.hosts;

      # The class-major fold. `realized` is self-referential: a host's `nodes` is `realized.<class>`,
      # the same set being built — lazy, so forcing one host's artifact never forces a peer's (the
      # spine is only the class's host keys, populated by `listToAttrs` names).
      realized = builtins.mapAttrs (
        className: terminal:
        builtins.listToAttrs (
          builtins.concatMap (
            hostName:
            let
              hc = hosts.${hostName};
              classModules = hc.classes.${className} or [ ];
            in
            if classModules == [ ] then
              [ ]
            else
              [
                {
                  name = hostName;
                  value =
                    let
                      # The per-host refinement layer, applied only when `bindings.<name>` is an
                      # attrset (a bare global value under a host-named key is not a refinement).
                      perHost = if builtins.isAttrs (bindings.${hostName} or null) then bindings.${hostName} else { };
                      mergedBindings = hc.bindings // bindings // perHost;
                    in
                    terminal (
                      {
                        name = hostName;
                        modules = classModules;
                        bindings = mergedBindings;
                        nodes = realized.${className};
                        extraModules = extraModules.${hostName} or [ ];
                      }
                      // (if hc ? osConfig then { inherit (hc) osConfig; } else { })
                    );
                }
              ]
          ) (builtins.attrNames hosts)
        )
      ) terminals;
    in
    realized;
in
{
  inherit project realize;
}
