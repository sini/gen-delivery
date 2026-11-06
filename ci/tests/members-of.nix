# `project`'s `membersOf` (den-hoag-ien5k T3, spec `specs/2026-11-01-ien5k-t3-syntactic-membership-spec.md` §2.3,
# §3a GR1): a caller's membership read, `node → [ member ] | null`, read through one binding (`membersAt`) at the
# three membership read sites (the lift's members edges, the ordered walk's start keys, the shared reach). `null`,
# or the option absent, reads the node's own `aspects`.
#   · `membersOf` absent and `membersOf = _: null` project the same nodes (ids and classes), and both equal the
#     projection of the same fixture (the control: nothing reads the option on main).
#   · a `membersOf` answering `[ "b" ]` for a node whose `aspects` is `[ "a" ]` delivers `b`'s content and not `a`'s.
# Red at gen-delivery main 6cc337a: `membersOf` is not an option of `project`, so its door refuses it by name.
{ genDelivery, mkFixture, ... }:
let
  fixture = mkFixture {
    cnf = {
      keySemantics.nixos.category = "class";
    };
    modules = [
      {
        config.aspects.a.nixos = { ... }: { };
        config.aspects.b.nixos = { ... }: { };
        config.aspects.b.includes = [ "c" ];
        config.aspects.c.nixos = { ... }: { };
        config.hosts.n1 = {
          addr = "10.0.9.1";
          aspects = [ "a" ];
        };
        config.hosts.n2 = {
          addr = "10.0.9.2";
          aspects = [ "b" ];
        };
      }
    ];
  };
  projectWith =
    opts: genDelivery.project ({ selectNodes = v: v.hosts; } // opts) fixture.cnf fixture.values;
  shape =
    p:
    builtins.mapAttrs (_: nd: {
      ids = nd.elementIds;
      classes = builtins.mapAttrs (_: builtins.length) nd.classes;
    }) p.nodes;
in
{
  flake.tests.members-of = {
    test-a-null-answer-reads-the-nodes-own-aspects = {
      expr = shape (projectWith {
        membersOf = _: null;
      });
      expected = shape (projectWith { });
    };
    test-an-answer-is-the-nodes-membership = {
      expr =
        (shape (projectWith {
          membersOf = n: if n == "n1" then [ "b" ] else null;
        })).n1;
      expected = (shape (projectWith { })).n2;
    };
    # the control: the two nodes' own memberships deliver different content, so the cell above can read red
    test-control-the-two-memberships-differ = {
      expr = (shape (projectWith { })).n1 == (shape (projectWith { })).n2;
      expected = false;
    };
  };
}
