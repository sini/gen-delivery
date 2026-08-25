# gen-delivery

The **delivery-class realization surface**: the projection that discovers which aspect keys are
declared delivery classes and reshapes the flat aspect registry per node, and the fold that hands
each class's collected content to its target-owned terminal.

```nix
genDelivery = inputs.gen-delivery.lib {
  algebra = inputs.gen-algebra.lib;
  aspects = inputs.gen-aspects.lib;
};

projected = genDelivery.project {
  values = composed.values;   # your own resolved config
  cnf = myAspectSchemaArgs;   # the mkAspectSchema argument you built your grammar from
};

realized = genDelivery.realize {
  inherit projected;
  terminals.nixos = carriage: mySystemBuilder carriage;
};
# => { nixos = { <node> = <artifact>; }; }
```

## Why it exists

A **delivery class** is content declared on an aspect, collected per node, and handed to a terminal
that turns it into an artifact. Two things have to be true of the surface that does this, and
neither was true of the code it replaces.

**The realization predicate must read the DECLARATION.** ADR-0028's Rider rules that a delivery
class realizes only on declared content, never on structural shape. The predecessor asked whether a
key's value was an attrset carrying an `imports` list — a shape test. It read clean on the
contentless arm only because gen-aspects happens to render a declared-but-unset class as `null`
rather than fabricating an empty deferred module: a representation choice in *another library*,
guarded here by a tripwire watching that choice. On a second axis it was simply wrong. A key
declared `category = "channel"` rides its value verbatim, so a channel carrying a module — the
cross-framework exchange payload the category exists for — was projected as a delivery class and had
its terminal called. A facet declared with a permissive option type does the same.

**The contribution order must be DECLARED.** The binding merge was a hardcoded positional `//`
chain whose only statement anywhere was a gloss in a header comment. It was compliant in kind
(ordered, positional, no strength lattice) and what it owed was that the order be explicit.

## The published surface

|                                                                                                        |                                                          |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| `project { values, cnf, selectHosts ? … }`                                                             | the flat aspect registry + the per-node build projection |
| `realize { projected, terminals, bindings ? {}, refinements ? {}, layerOrder ? …, extraModules ? {} }` | class-major artifacts, `{ <class>.<node> = artifact; }`  |
| `defaultLayerOrder`                                                                                    | the contribution-order declaration, readable             |

### the realization predicate

A key of a flat-registry aspect entry is a delivery class **iff both**:

1. it is **declared** `category = "class"`, read through gen-aspects' single classification surface
   and never re-derived here; **and**
2. it **carries content** at that entry.

Shape is never consulted for classification. Limb 1 closes the wrong-category arms; limb 2 closes
the contentless arm independently of how gen-aspects chooses to represent absence — including the
fabricated empty deferred module, which is the state the Rider's hazard turns on and the state no
fixture built through gen-aspects can exhibit.

**The two absences go opposite ways, and collapsing them is the harmful reading.** Constructed with
**no category source** the surface refuses by name: a default there would silently degrade to the
shape test being removed. A **key** whose category is `null` is the ordinary state of a nested
aspect — `null` is gen-aspects' documented answer for an unregistered key — so it is simply not a
delivery class and nothing throws. The refusal owed for an unrecognised key already exists upstream
at schema construction; duplicating it here would throw on every nested aspect in the corpus.

### the declared contribution order

Three named contribution layers, folded least-specific first by `algebra.record.foldLayers`:

| layer        | what contributes it                                    |
| ------------ | ------------------------------------------------------ |
| `projection` | the projection's own `{ node = <resolved instance>; }` |
| `global`     | `bindings`, one attrset applied to every node          |
| `refinement` | `refinements.<node>`, the caller's per-node entry      |

`defaultLayerOrder` is `[ "projection" "global" "refinement" ]` — a declaration with a default
value, published so a consumer can read it rather than only override it. Naming a layer that does
not exist refuses by name; naming a subset drops the omitted layer's contribution.

The **global** and **refinement** layers are separate inputs, and that is a fix rather than a shape.
They used to be one attrset carrying both, with per-node refinements under node-named keys and a
runtime `isAttrs` guess telling them apart. The consequence was admitted in the predecessor's own
header: a node-named refinement key also rode into every node's merged bindings as a literal
binding, surprising whenever a formal happened to share a node name. An explicit layer list cannot
be written while one layer is nested inside another.

**The fold is not written here.** `record.foldLayers` is an ordered layer list, last wins, no
strength lattice, unknown per-field strategy refused by name. What this surface writes is the layer
*declaration*. No `strategies` are passed: the default is `replace`, measured equal to the
positional chain this merge has always been.

### the terminal contract

| field          |                                                                               |
| -------------- | ----------------------------------------------------------------------------- |
| `name`         | the node's registry key                                                       |
| `modules`      | this class's deferred-module list, opaque and unforced                        |
| `bindings`     | the contribution layers folded in the declared order                          |
| `extent`       | the realized set for **this class only**; its spine is the class's node keys  |
| `extraModules` | the per-node extras (`[]` when absent)                                        |
| `passthrough`  | the target-owned channel, present iff the node's projection entry carries one |

## The names

Framework naming never becomes substrate vocabulary, so the three names the predecessor carried are
resolved rather than relocated.

- **`host` → `node`.** `node` is ruled substrate vocabulary: a position with attributes and incident
  labelled edges, of which a registry instance is a view. `host` is attested in the archived corpus
  only in the unrelated DSL-embedding sense ("host language"), so its presence there is not support.
- **`nodes` → `extent`.** The old name collided with the ruled term while meaning something else:
  the field holds realized *artifacts keyed by node*. The extent of a predicate is the set of
  objects of the universe for which it holds (Gelfond & Lifschitz 1988, stable model semantics), and
  realization is a predicate. **Precisely:** the field is not the extent — its *spine* is. Naming a
  container after its index set would mirror the error being corrected.
- **`osConfig` → `passthrough`.** No substrate term should exist for it. `osConfig` is a
  nixpkgs/home-manager identifier, correct as surface vocabulary *at the surface* and wrong as a
  pinned field in a substrate-facing contract. The contract carries one target-owned channel, opaque
  here, whose keys are the consumer's own. The name is minted from the ruling's own words and
  carries no theory citation.

`selectHosts` deliberately keeps its name: the override merge law's REPLACE clause names that formal
and the law does not move with this surface.

`modules`, `bindings` and `name` are out of scope: the module system's own vocabulary, the
substrate's relation vocabulary, and the member's key.

## What it does not do, and does not claim

- **`extent` is not on a governed query surface.** No mark, no narrowing operator, widening
  trivially expressible by a caller who holds the realized set. The suite pins the accessor's
  contract as built — per-class, lazy — and does not stand in for that surface.
- **It never evaluates.** The terminal does. Class bodies cross into a target's evaluation
  unforced, and this library is nixpkgs-lib-free with no sanctioned boundary at all.
- **It reads no declaration it was not given.** The key-category declaration arrives as an argument.
  This library republishes no gen-aspects accessor and no algebra constructor under a name of its
  own.

## Running the suites

```sh
nix-unit --flake ./ci#tests        # the suites
nix-unit --flake ./ci#testsError   # cells whose subject is an error MESSAGE
```

Read the exit status **unpiped** — under zsh a pipeline's per-stage status is `$pipestatus`,
lowercase, and a piped read of `$?` reports the last stage instead of nix-unit.

```sh
cd ci && nix fmt -- --ci           # formatting, before every commit
```
