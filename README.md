# gen-delivery

The **delivery-class realization surface**: the projection that discovers which aspect keys are
declared delivery classes and reshapes the flat aspect registry per node, and the fold that hands
each class's collected content to its target-owned terminal.

```nix
genDelivery = inputs.gen-delivery.lib {
  algebra = inputs.gen-algebra.lib;
  aspects = inputs.gen-aspects.lib;
  prelude = inputs.gen-prelude.lib;
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

**The realization predicate must read the DECLARATION.** A delivery class realizes only on
declared content, never on structural shape. The predecessor asked whether a
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

|                                                                                                        |                                                                                                           |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `project { values, cnf, selectNodes, deliveryClasses ? {}, instances ? {} }`                           | the flat aspect registry + the per-node build projection, over the include closure of each node's members |
| `realize { projected, terminals, bindings ? {}, refinements ? {}, layerOrder ? …, extraModules ? {} }` | class-major artifacts, `{ <class>.<node> = artifact; }`                                                   |
| `defaultLayerOrder`                                                                                    | the contribution-order declaration, readable                                                              |

### the include closure

A node receives the content of its members **and of everything they include**. `project` walks
gen-aspects' published include sites (`graphFacts`' `includeSitesOf`) breadth-first from the node's
members, in declared order:

- a **reference** to an aspect delivers that aspect, once per node however many paths reach it; an
  include cycle between named aspects terminates;
- **inline content** written at an include position (an aspect literal, or the part gen-aspects
  coerces a split aspect's `{ config, ... }:` definition into) is delivered at its position, and
  its own includes are followed the same way, so an aspect split across modules delivers every part;
- a reference into a tree this one does not hold is **refused by name** (federate the trees first);
- a **parametric aspect** (a guard, or an aspect folded into a guard carrier) is delivered through
  its **instances**, read from `instances`, gen-aspects' instance relation (`instancesFor`): at the
  node, the instances `reaches.<node>.<aspect>` lists; inside an instance, those its
  `nested.<instance>.<aspect>` lists. Each instance delivers its vertex's `entry`, and its includes are
  followed the same way. A static aspect is always walked at node scope, wherever it is reached.
  `project` reads the relation and never mints an instance;
- where the relation lists no instance, the reach **refuses by name**: a scope it was never handed
  (no `instances`, or a node missing from `reaches`) and a guard carrier by the no-instance door; a
  first-order guard in a handed scope as **undecided**. That last refusal is interim: the relation
  does not publish whether the producer declined the guard (its condition FALSE) or never walked it
  (a member omitted from the scope, other sources, another tree), and delivering nothing would
  silently drop a TRUE guard in the second case. Once gen-aspects publishes the declined set, a
  declined guard delivers nothing, as an edge whose condition is off is no edge at all;
- **parametric content with no declaration** (a guard written at an include position, or a named
  guard included by value) is refused by name: the relation can hold no instance of it. A
  `{ host, ... }:` include is refused upstream by gen-aspects.

**The caller's obligation.** `instances` must be minted over the same `values.aspects` and `cnf`
`project` reads. An instance id names its declaration and formals, never its class content, so a
relation minted over another tree delivers that tree's content at rc 0. Every `project` call carrying `instances`
forces the whole relation at its root, a `bindings` read included.

`instances` refuses by name when it is not the four-field record `{ vertices; instantiates; reaches; nested; }` of attrsets, and where the walk reads it: an edge set or edge list of the wrong
type, an id that is not a string, an id with no vertex, a vertex without an attrset `entry`, and an
instance listed under an aspect its `instantiates` edge does not name.

A member is an aspect **identifier** (its key), resolved through `graphFacts`' `nodeIdOf`; a member
naming no aspect, or written as a declaration value, is refused by name. Every refusal fires only
for a node that reaches the bad include. The order is breadth-first by default, and that default is
reversible.

### the delivery-class map

`deliveryClasses = { <node> = { <authored class> = <delivery class>; }; }` keys a node's content for
an authored class under the delivery class it names, so one projection realizes on several
terminals, for example one per pin. An absent map is `{ }` and an absent entry is the identity.
Content is still collected by authored class, so one authored class's list moves whole, in closure
order. `realize` reads only delivery classes, so `extent` and `extraModules` are per delivery class.

The map is data derived from the caller's values, never from the projection. These refuse by name:

- at `project`'s root: a map or an entry that is not an attrset, an entry naming a node the
  projection does not carry, an authored class not declared `class` in `cnf`, and a target that is
  not one string. The node set is read only when the map is non-empty;
- on the node's `classes`: two authored classes **with content** at one node landing in one delivery
  class, where their contents would merge in one terminal. `bindings` stays readable.

An entry for a class the node has no content for is accepted and changes nothing: a caller cannot
know where content is without reading the projection. A delivery class with content and no terminal
is `realize`'s existing refusal.

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
value, published so a consumer can read it rather than only override it.

**The order is TOTAL over the layers, in both directions, and both refuse by name.** Naming a layer
that does not exist refuses; so does omitting one. An omitted layer is a *deleted contribution*, not
a shorter list — drop `projection` and `bindings.node`, which the contract documents as always
present, silently vanishes and the terminal that reads it fails deep inside the target. The
precondition is a declared *total* order, and one direction guarded is not that.

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
| `extraModules` | the extras addressed to **this class** at this node (`[]` when absent)        |
| `passthrough`  | the target-owned channel, present iff the node's projection entry carries one |

### the addressed inlet

`realize`'s `extraModules` is **class-major**, `{ <class>.<node> = [ module ]; }`, the output's own
coordinate: `extraModules.a.n` lands in `realized.a.n` and nowhere else. It is how a value crosses
from one class to another — the caller adapts it and addresses it to the target class. Extras
supplement a realization and never create one, so an address that names no point of the realization
refuses by name: the retired node-keyed shape, a class with no terminal, an unprojected node, and a
node with no declared content for the class.

Declared content is an address too. A node whose projection carries content for a class with no
terminal refuses by name, where it would otherwise vanish from the realization. The refusal is
forced with the result itself, so any read of it, including its class names, sees it; it reads each
node's class names, never the content of a class that has a terminal.

The inlet is opaque. It holds that no crossing is implicit and that an explicit one lands only where
it is addressed; it does not check that the caller adapted what it addressed.

**Neither an address set nor a projection may be derived from `realize`'s own output.** The checks
read every address before the realization they guard can be observed, so a self-derived one diverges
with an uncatchable infinite recursion. Derive the addresses from the projection, and the projection
from the values.

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

- **`selectHosts` → `selectNodes`.** The same substitution applied to the formal that selects the
  node instances; `select` is the verb gen-graph's `selectEdges` already carries.

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
nix develop ./ci --command ci                # the suites, guarded
nix develop ./ci --command ci --tests-error  # cells whose subject is an error MESSAGE, guarded
nix-unit --flake ./ci#tests                  # the suites, unguarded
nix-unit --flake ./ci#testsError             # the error cells, unguarded
```

`ci` refuses when anything under a declared read root is unknown to git — any extension or name,
`_`-prefixed included — and the remedy is `git add` or a move. The bare `nix-unit` and
`nix flake check` forms are unguarded: they read a git-filtered copy of the tree, so an untracked
cell is silently absent and the run stays green.

Read the exit status **unpiped** — under zsh a pipeline's per-stage status is `$pipestatus`,
lowercase, and a piped read of `$?` reports the last stage instead of nix-unit.

```sh
cd ci && nix fmt -- --ci           # formatting, before every commit
```
