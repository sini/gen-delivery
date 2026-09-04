# gen-delivery agent sheet

The delivery-class realization surface. Zero root inputs; substrate injected; nixpkgs-lib-free.
`lib/default.nix` is the whole library — one file, because the row this executes calls the
projection and the fold **one construct** and they are one: the realization predicate lives in the
first half and the fold that trusts it lives in the second.

## published surface

`{ algebra, aspects }` in; `{ project, realize, defaultLayerOrder }` out.

|                     | signature                                                                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `project`           | `{ values, cnf ? null, selectHosts ? (v: v.hosts or {}) } -> { aspects, nodes }`                                                                 |
| `realize`           | `{ projected, terminals, bindings ? {}, refinements ? {}, layerOrder ? defaultLayerOrder, extraModules ? {} } -> { <class>.<node> = artifact; }` |
| `defaultLayerOrder` | `[ "projection" "global" "refinement" ]`                                                                                                         |

`project.aspects` is the flat registry (`aspects.flatten values.aspects`, empty when there is no
`aspects` surface). `project.nodes` is the per-node build projection,
`{ <node> = { bindings = { node = <instance>; }; classes = { <class> = [ deferredModule ]; }; }; }`.
A consumer may extend an entry with `passthrough`; nothing here emits it.

## the two refusals, and why they are not one

| case                                                               | behaviour                                     |
| ------------------------------------------------------------------ | --------------------------------------------- |
| `cnf` absent — the surface was constructed with no category source | **REFUSES BY NAME**, at the projection's root |
| a KEY's category is `null` or is not `"class"`                     | **not a delivery class. No refusal.**         |

The second row is load-bearing. `keyCategory` answers `null` for an unregistered key *by contract*,
and an undeclared key is the ordinary shape of a nested aspect — a per-key refusal here would throw
on every nested aspect in the corpus, and it would duplicate a ruled refusal that already fires
upstream at schema construction. The delivery surface refuses on its own missing **input**; it never
adjudicates someone else's key.

The `cnf` refusal is forced by a `seq` at the projection's root rather than where the predicate
reads it. **A registry with no member aspects never reaches the predicate**, so a lazy refusal would
fire on the SIZE of the input instead of on the input's absence, and a small fixture would read
clean.

`layerOrder` is refused the same way and for the same reason — at `realize`'s root, both directions.
The order is TOTAL over the layers: naming an unknown layer refuses, and so does omitting a declared
one, because an omitted layer is a *deleted contribution* rather than a shorter list. Wired into the
per-node fold instead, the check would fire on the size of the input.

## traps and measured facts

<!-- gen-citations:begin -->

|                                                                                                                                                                                                                                                                                                                                              |                                             |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **`deepSeq` does not evaluate a class body.** The rendered class value is `{ imports = [ { _file; imports = [ <lambda> ]; } ]; }` and a lambda is already in WHNF. A laziness cell built on `deepSeq` measures nothing; the control must **apply** the body                                                                                  | `ci/tests/class-content.nix`                |
| **A bare facet declaration never reaches the entry.** `category = "facet"` with no `option`/`module` in its keySemantics adds nothing under the key name, so a probe using the bare form reads a FALSE ABSENCE. Declared WITH a permissive `option`, a facet does appear at the entry's top level and the old structural predicate admits it | measured at `gen-aspects 29fc7cc`           |
| **import-tree skips any path whose basename starts with `_`.** A cell file named \_x.nix is collected by nothing and its absence reads as a pass                                                                                                                                                                                             | caught by a seeded-failure control          |
| **`checks.default` cannot host an `expectedError` cell.** The batch asserter forces every `expr` unconditionally, so a throwing cell with no `expected` CRASHES the gate instead of failing it                                                                                                                                               | `ci/tests-error.nix`, on `flake.testsError` |
| **A declared class with content is `{ imports = [ … ]; }` — exactly one key.** `hasContent` tests the whole key set rather than `imports` alone, so a module carrying a definition beside an empty `imports` still counts as content                                                                                                         | `lib/default.nix`                           |

<!-- gen-citations:end -->

## what the suites hold

| suite                   | subject                                                                                                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `declared-content`      | the Rider through a REAL gen-aspects schema — the rendering half                                                                                                                                  |
| `realization-predicate` | the Rider through a HAND-BUILT registry — the predicate half, including the fabricated-empty state gen-aspects never produces, both wrong-category arms, and the input-absence / key-absence pair |
| `carriage`              | the terminal contract, the split weld, the rename observed at the SITES, and the target-facing key                                                                                                |
| `contribution-order`    | the declared layer order, the permutation pair, namespace separation                                                                                                                              |
| `extent`                | the accessor's laziness and its per-class narrowness                                                                                                                                              |
| `class-content`         | class bodies never evaluated (as a PAIR), multiple definitions per class per node                                                                                                                 |
| `purity`                | no nixpkgs anywhere under `lib/`                                                                                                                                                                  |

★ **The rename cells are SITE-SCOPED, and that is not stylistic.** They read the key set the fold
actually emits, never tokens in a file. A token-scoped version of the same claim goes green by
renaming *correct* uses of the ruled term elsewhere in a tree — it passes on the broken outcome.

★ **The weld cells are the ones that catch the wrong fix.** `carriage` carries two adapters over one
carriage: one built on the split weld, one that renamed *through* it. Their target argument sets
differ (`nodes` against `extent`). Without that pair the correct migration and the sweep-produced
one look identical from the carriage side, because the carriage is renamed in both.

## running the suites

```sh
nix-unit --flake ./ci#tests
nix-unit --flake ./ci#testsError
```

Read the exit status UNPIPED — under zsh the per-stage status of a pipeline is `$pipestatus`,
lowercase. Count `☢️` as well as `❌`: a cell that aborts the suite is a failure, not a skip. A run
reading `0/0` is a false pass; prove collection with a named failing cell before trusting a green.

## formatting

```sh
cd ci && nix fmt -- --ci
```

`--ci` fails on change *after* writing the change, so a first run that reports `1 changed` has
already applied it — re-run and read `0 changed`.

## Drift check

`nix eval --json .#lib --apply builtins.attrNames` — the form 23 sibling sheets publish —
**aborts here**. The library is a function of `{ algebra, aspects }`, so the flake's `lib` output is
a lambda and the apply reads *"expected a set but found a function"*. The check has to supply a
substrate, and it supplies the ACCEPTANCE RUN's own — `ci/flake.nix`'s `gen-algebra` and
`gen-aspects`, resolved through `ci/flake.lock` — rather than pinning a second one, which would make
the checked surface a different construction from the tested one. There is no `ci/repl.nix` here, so
the splice is inline; resolving a local flake from an expression is what `--impure` pays for. From
the repository root:

```sh
nix eval --json --impure --expr 'let ci = builtins.getFlake (toString ./ci); in builtins.attrNames (import ./lib { algebra = ci.inputs.gen-algebra.lib; aspects = ci.inputs.gen-aspects.lib; })'
```

Current output (verbatim):

```json
["defaultLayerOrder","project","realize"]
```
