# CLASS CONTENT — that it is never EVALUATED here, and that MULTIPLE definitions survive.
#
# Both cells run against a REAL gen-aspects schema, because both are claims about what happens to a
# rendered deferredModule rather than to an attrset shaped like one.
#
# ★ THE LAZINESS CELL IS A PAIR, AND THE PAIR IS THE POINT. The predecessor suite asserted only that
# a class value's `.imports` is a list, which is satisfied by a class body that could not have been
# forced in the first place: a green read there cannot tell "not forced" from "nothing to force".
# The body here THROWS WHEN APPLIED, and the control applies it — so the clean read is a body that
# was never evaluated rather than a body that could not complain.
#
# Measured, and it is why the control is an APPLICATION and not a `deepSeq`: the rendered class
# value is `{ imports = [ { _file; imports = [ <lambda> ]; } ]; }`, and a lambda is already in weak
# head normal form. `deepSeq` walks straight past it. A cell that forced the value deeply and read
# clean would be measuring nothing at all.
{ genDelivery, mkFixture, ... }:
let
  fixture = mkFixture {
    cnf = {
      keySemantics.nixos.category = "class";
    };
    modules = [
      {
        # A body that throws WHEN APPLIED. Nothing in the projection or the fold applies it.
        config.aspects.web.nixos = { ... }: throw "gen-delivery test: class body evaluated";
        # TWO aspects contributing to the SAME class, and `n1` is a member of both — so the class's
        # module list for one node has two contributors rather than one.
        config.aspects.db.nixos = { ... }: { };
        config.hosts.n1 = {
          addr = "10.0.9.1";
          aspects = [
            "web"
            "db"
          ];
        };
      }
    ];
  };

  projected = genDelivery.project { inherit (fixture) values cnf; };

  # A terminal that reports the shape of what it was handed WITHOUT evaluating any of it.
  countingTerminal =
    { name, modules, ... }:
    {
      inherit name;
      count = builtins.length modules;
      allCarryImports = builtins.all (v: v ? imports) modules;
    };

  realized = genDelivery.realize {
    inherit projected;
    terminals.nixos = countingTerminal;
  };

  # The rendered body, reached by its measured shape. This is the instrument the control applies.
  bodyOf = classValue: builtins.head (builtins.head classValue.imports).imports;
  webBody = bodyOf (projected.aspects.web.nixos);

  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;
in
{
  flake.tests.class-content = {
    # ── O3: the class body is never evaluated by the projection or the fold ──
    test-projection-does-not-evaluate-the-class-body = {
      expr = forces projected.nodes.n1.classes;
      expected = true;
    };
    test-realization-does-not-evaluate-the-class-body = {
      expr = forces realized.nixos.n1;
      expected = true;
    };
    # POSITIVE CONTROL, same run, same body: APPLYING it throws. This is what the predecessor cell
    # never had, and without it the two reads above are green over an inert value.
    test-control-applying-the-class-body-throws = {
      expr = (builtins.tryEval (webBody { })).success;
      expected = false;
    };
    # …and the control's instrument really did reach a function, so the throw above is the body's
    # and not a type error on the way to it.
    test-control-the-body-reached-is-a-function = {
      expr = builtins.isFunction webBody;
      expected = true;
    };

    # ── O4: multiple definitions of one class for one node survive as separate contributions ──
    # `collectClass` concatMaps over the node's member aspects. A predicate change that dropped one
    # contributor, or a reshape that merged them, reads as a shorter list here and nowhere else.
    test-two-aspects-contribute-two-modules-to-one-class = {
      expr = realized.nixos.n1.count;
      expected = 2;
    };
    # CONTROL — the count is over real rendered deferredModules, not over whatever happened to be
    # in the list. Both entries carry an `imports` field, which an accidental extra element (a null
    # from an unset class, say) would not.
    test-control-both-contributions-are-deferred-modules = {
      expr = realized.nixos.n1.allCarryImports;
      expected = true;
    };
    # CONTROL — the node is genuinely a member of both aspects, so the 2 above is not one aspect
    # counted twice.
    test-control-node-is-a-member-of-both-aspects = {
      expr = fixture.values.hosts.n1.aspects;
      expected = [
        "web"
        "db"
      ];
    };
  };
}
