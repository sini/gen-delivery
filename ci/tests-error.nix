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
in
{
  flake.testsError = {
    # The caller-supplied selector must return the instance registry. A non-attrset result would
    # otherwise die inside `mapAttrs` as an anonymous "expected a set", naming neither the surface
    # nor the argument that produced it.
    test-select-hosts-non-attrset-refuses-by-name = {
      expr =
        (genDelivery.project {
          values = { };
          selectHosts = _: "not an attrset";
        }).nodes;
      expectedError.msg = exactly "gen-delivery: project: selectHosts must return an attrset of node instances ({ <node> = <instance>; }), got string";
    };
  };
}
