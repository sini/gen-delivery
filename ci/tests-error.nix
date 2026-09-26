# THE SECOND TEST OUTPUT — cells whose subject is an ERROR MESSAGE, and why they cannot live in
# `flake.tests`.
#
# THAT a construction refuses is a boolean and `tryEval` asserts it; those cells live in the suites.
# WHICH refusal fired is a claim about the message, and `tryEval` returns `{ success, value }` and
# DISCARDS the text — so a suite of booleans alone is equally satisfied by a construction with one
# refusal in it, and a reworded message regresses nothing any cell reads. nix-unit's `expectedError`
# is the assertion for that, and this is where it goes.
#
# ★ WHY A SECOND OUTPUT RATHER THAN A SECOND SUITE. The batch asserter behind `checks.default`
# evaluates `t.expr == t.expected` UNCONDITIONALLY and quantifies over `config.flake.tests` and
# nothing else, so a cell with no `expected` and a throwing `expr` CRASHES that gate rather than
# failing it. Hosting these on `flake.testsError` puts them outside that quantifier while keeping
# them live on the nix-unit path. The split is structural, not conventional: this file is not under
# ./tests, which is the whole of `testModules`.
#
#   nix-unit --flake ./ci#tests        # the suites
#   nix-unit --flake ./ci#testsError   # these cells
#
# ★★ `expectedError.msg` IS SEARCHED, NOT WHOLE-MATCHED, so a pattern naming a PREFIX of the message
# passes against a message that says something else after it — which would make these cells agree
# with the very rewording they exist to catch. Every pattern below is anchored at both ends and
# built by ESCAPING THE LITERAL TEXT rather than by hand.
{ genDelivery, lib, ... }:
let
  exactly = msg: "^" + lib.escapeRegex msg + "$";

  # Held as one binding because the text is long enough that inlining it beside the `exactly` call
  # invites a `+` that binds looser than the application and silently anchors only its first term.
  missingCategorySource =
    "gen-delivery: project: no category source — `cnf` is required and has no default. "
    + "The realization predicate reads the key-category declaration; with none it could only fall "
    + "back to a structural shape test.";

  noNodeSelector =
    "gen-delivery: project: no node selector — `selectNodes` is required and has no default. It "
    + "names WHICH resolved attrset of the caller's values holds the node instances.";

  duplicateLayer =
    "gen-delivery: realize: layerOrder repeats contribution layer(s) projection — a sequence with "
    + "duplicates is not an order, and the LAST occurrence would decide, silently inverting the "
    + "declared precedence";

  retiredNodeKeyedShape =
    "gen-delivery: realize: extraModules.n is not an attrset — extraModules is CLASS-MAJOR, "
    + "{ <class>.<node> = [ module ]; }; the node-keyed { <node> = [ module ]; } shape was retired "
    + "because it reached every class's terminal";

  noDeclaredContent =
    "gen-delivery: realize: extraModules.a.m addresses a node with no declared a content — a does "
    + "not realize there (ADR-0028's Rider), so the extras would be dropped";

  # The address fixture: `n` carries a and b content, `m` carries b only; terminals a and b.
  addressed =
    extraModules:
    genDelivery.realize {
      projected.nodes = {
        n = {
          bindings = { };
          classes = {
            a = [ { from = "a"; } ];
            b = [ { from = "b"; } ];
          };
        };
        m = {
          bindings = { };
          classes.b = [ { from = "b"; } ];
        };
      };
      terminals = {
        a = args: args;
        b = args: args;
      };
      inherit extraModules;
    };
in
{
  flake.testsError = {
    # THE MISSING DECLARATION INPUT. Its suite cell asserts THAT the surface refuses; this one
    # asserts it refuses AS the missing category source, which is the half that distinguishes it
    # from the refusal below and from any other throw the projection could produce.
    test-missing-category-source-names-the-input = {
      expr = (genDelivery.project { values = { }; }).aspects;
      expectedError.msg = exactly missingCategorySource;
    };

    # THE MISSING NODE SELECTOR — the root cause of the hub's silent empty. A default here
    # (`v: v.<name> or { }`) turned a registry spelled anything but `<name>` into a well-typed empty
    # one; the formal now has no default and names itself. `cnf.keySemantics = { }` is LOAD-BEARING,
    # not decoration: the declaration must be present or `requireCnf` fires first under `project`'s
    # `seq` and this cell would assert the wrong refusal while still reading green.
    test-missing-node-selector-names-the-formal = {
      expr =
        (genDelivery.project {
          values = { };
          cnf.keySemantics = { };
        }).nodes;
      expectedError.msg = exactly noNodeSelector;
    };

    # The caller-supplied selector must return the instance registry. A non-attrset result would
    # otherwise die inside `mapAttrs` as an anonymous "expected a set", naming neither the surface
    # nor the argument that produced it. The declaration IS present here, so the two refusals are
    # reachable independently rather than one shadowing the other.
    test-select-nodes-non-attrset-refuses-by-name = {
      expr =
        (genDelivery.project {
          values = { };
          cnf.keySemantics = { };
          selectNodes = _: "not an attrset";
        }).nodes;
      expectedError.msg = exactly "gen-delivery: project: selectNodes must return an attrset of node instances ({ <node> = <instance>; }), got string";
    };

    # A DUPLICATED layer in `layerOrder`. The seeded shape keeps every declared layer present and
    # names no unknown one, so neither sibling refusal in the totality check is reachable — only the
    # duplicate clause can throw here, and the pattern asserts the duplicated layer is NAMED. The
    # empty projection makes the same point the suite's no-nodes cell does: the check is forced at
    # realize's root, not inside the per-node fold.
    test-duplicate-layer-refuses-by-name = {
      expr = genDelivery.realize {
        projected.nodes = { };
        terminals.nixos = args: args;
        layerOrder = [
          "projection"
          "projection"
          "global"
          "refinement"
        ];
      };
      expectedError.msg = exactly duplicateLayer;
    };

    # ── THE ADDRESSED INLET: every address a point of the realization, or a refusal by name ──
    # R0 — THE RETIRED NODE-KEYED SHAPE. The honest migration mistake: read as class `n`, it would be
    # dropped silently. Refused at the root, so the result's own WHNF names it.
    test-node-keyed-extras-refuse-as-the-retired-shape = {
      expr = addressed { n = [ { x = 1; } ]; };
      expectedError.msg = exactly retiredNodeKeyedShape;
    };
    # R1 — the class has no terminal, so nothing realizes it.
    test-extras-for-a-class-with-no-terminal-refuse-by-name = {
      expr = addressed { d.n = [ { x = 1; } ]; };
      expectedError.msg = exactly "gen-delivery: realize: extraModules.d.n addresses class d, which has no terminal — the extras would be dropped";
    };
    # R2 — the node is not projected. Refused on the addressed class's spine.
    test-extras-for-an-unprojected-node-refuse-by-name = {
      expr = (addressed { a.z = [ { x = 1; } ]; }).a;
      expectedError.msg = exactly "gen-delivery: realize: extraModules.a addresses node z, which the projection does not carry — the extras would be dropped";
    };
    # R3 — the node carries no declared content for the class, so the class does not realize there
    # and the extras cannot create a realization. `m` IS projected (it realizes b), so R2 cannot
    # shadow this refusal.
    test-extras-where-the-class-does-not-realize-refuse-by-name = {
      expr = (addressed { a.m = [ { x = 1; } ]; }).a;
      expectedError.msg = exactly noDeclaredContent;
    };
  };
}
