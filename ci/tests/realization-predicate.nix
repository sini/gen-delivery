# THE REALIZATION PREDICATE READS THE DECLARATION — the cells the surrounding suite cannot host.
#
# The declared-content suite runs its fixture through a REAL gen-aspects schema, which is what makes
# its reading trustworthy and also what bounds it: gen-aspects renders a declared-but-unset class as
# `null`, so the state where a contentless class reads `{ imports = [ ]; }` is one that library
# never produces. That state is exactly the Rider's hazard, and the only way to exhibit it is to
# hand the surface a registry directly. These cells do that, and they are the difference between a
# Rider discharged by another library's representation choice and one held by construction here.
#
# The registry below is therefore HAND-BUILT, and the fixture is honest about what that costs: it
# proves the predicate, not the rendering. The rendering is measured next door.
{ genDelivery, ... }:
let
  m = { ... }: { };

  # THE DECLARATION. Four keys, one of each category that can carry an attrset value, plus a key
  # declared nowhere at all — which is the ordinary shape of a nested aspect and must NOT refuse.
  cnf = {
    keySemantics = {
      nixos.category = "class";
      metrics.category = "class";
      chan.category = "channel";
      facetKey.category = "facet";
    };
  };

  # EVERY key below carries the SAME value shape — an attrset with an `imports` list. That is the
  # point: under a structural predicate all four are indistinguishable, so the only thing that can
  # tell them apart is the declaration.
  withImports = {
    imports = [ m ];
  };

  registry = {
    web = {
      name = "web";
      nixos = withImports;
      # THE FABRICATED EMPTY deferredModule — a class DECLARED and given nothing, in the
      # representation gen-aspects does not currently use. This is the arm the old predicate
      # cannot survive.
      metrics = {
        imports = [ ];
      };
      # A channel carrying a module. The category's own contract is that its value rides
      # VERBATIM, and a module travelling through a channel is the cross-framework exchange
      # payload the category exists for — so this is realizable input, not a contrivance.
      chan = withImports;
      # A facet declared with an option type permissive enough to hold the same shape. Measured
      # against gen-aspects: such a facet DOES appear at the entry's top level under its key
      # name, and the structural predicate admits it there.
      facetKey = withImports;
      # Declared nowhere — `keyCategory` answers `null` for it, which is the documented answer for
      # an unregistered key and the ordinary state of a nested aspect.
      nested = withImports;
    };
  };

  values = {
    aspects = registry;
    hosts.n1 = {
      name = "n1";
      aspects = [ "web" ];
    };
  };

  # `project` flattens `values.aspects` through gen-aspects; the registry above is already flat, and
  # `flatten` over a flat tree is the identity on it, so the fixture reaches the predicate unchanged.
  projected = genDelivery.project { inherit values cnf; };

  tripwire = { name, ... }: throw "gen-delivery test: terminal invoked for `${name}`";
  realizedTripwire = genDelivery.realize {
    inherit projected;
    terminals = {
      nixos = tripwire;
      metrics = tripwire;
      chan = tripwire;
      facetKey = tripwire;
      nested = tripwire;
    };
  };
  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;

  refuses = thunk: !(builtins.tryEval thunk).success;
in
{
  flake.tests.realization-predicate = {
    # ── O-DECL-1: the ruled fix, BY CONSTRUCTION ──
    # A class declared but contentless realizes no node, in the representation the old predicate
    # could not survive. `metrics` reads `{ imports = [ ]; }` here, so `isAttrs && ? imports &&
    # isList imports` — the whole of the old test — is TRUE of it. It is excluded anyway, at limb 2.
    test-fabricated-empty-class-is-not-projected = {
      expr = builtins.elem "metrics" (builtins.attrNames projected.nodes.n1.classes);
      expected = false;
    };
    test-fabricated-empty-class-realizes-no-node = {
      expr = builtins.attrNames realizedTripwire.metrics;
      expected = [ ];
    };
    # CONTROL in the same run — the content-given class over the same fixture IS projected, so the
    # exclusion above is a discrimination on content and not a projection that is simply empty.
    test-control-content-class-is-projected = {
      expr = builtins.elem "nixos" (builtins.attrNames projected.nodes.n1.classes);
      expected = true;
    };
    # CONTROL — the tripwire CAN fire, on the class that does have content, same run.
    test-control-tripwire-fires-for-the-content-class = {
      expr = forces realizedTripwire.nixos;
      expected = false;
    };

    # ── O-DECL-2: the wrong-category arms ──
    # A channel carrying a module is NOT a delivery class, however its value is shaped, and its
    # terminal is never invoked.
    test-channel-carrying-a-module-is-not-a-class = {
      expr = builtins.elem "chan" (builtins.attrNames projected.nodes.n1.classes);
      expected = false;
    };
    test-channel-terminal-is-never-invoked = {
      expr = forces realizedTripwire.chan;
      expected = true;
    };
    # The facet arm, same value shape, same result. This arm was unmeasured when the surface was
    # specified; it is measured here and it behaves exactly like the channel.
    test-facet-carrying-a-module-is-not-a-class = {
      expr = builtins.elem "facetKey" (builtins.attrNames projected.nodes.n1.classes);
      expected = false;
    };
    test-facet-terminal-is-never-invoked = {
      expr = forces realizedTripwire.facetKey;
      expected = true;
    };
    # ★ THE SEEDED DEFECT, kept live: the OLD predicate applied to the SAME entry admits all four
    # of the shape-identical keys. Without this the four exclusions above could be a predicate that
    # excludes everything, and the fix would be indistinguishable from a broken projection.
    test-control-old-structural-predicate-admits-all-four = {
      expr = builtins.filter (
        k:
        let
          v = registry.web.${k};
        in
        builtins.isAttrs v && v ? imports && builtins.isList v.imports
      ) (builtins.attrNames registry.web);
      expected = [
        "chan"
        "facetKey"
        "metrics"
        "nested"
        "nixos"
      ];
    };
    # …and the new one admits exactly the declared class that carries content.
    test-declared-content-class-is-the-only-one-projected = {
      expr = builtins.attrNames projected.nodes.n1.classes;
      expected = [ "nixos" ];
    };

    # ── O-DECL-3b: an undeclared KEY does not refuse ──
    # `nested` is in no `keySemantics` at all, which is the ordinary shape of a nested aspect and a
    # state `keyCategory` answers `null` for BY CONTRACT. The entry evaluates normally, the key is
    # simply not a delivery class, and the entry's declared class still projects. A per-key refusal
    # here would throw on every nested aspect in the corpus — the harmful reading of a rule whose
    # other half is a genuine refusal.
    test-undeclared-key-does-not-refuse = {
      expr = forces projected.nodes.n1.classes;
      expected = true;
    };
    test-undeclared-key-is-not-a-delivery-class = {
      expr = builtins.elem "nested" (builtins.attrNames projected.nodes.n1.classes);
      expected = false;
    };
    test-undeclared-key-terminal-is-never-invoked = {
      expr = forces realizedTripwire.nested;
      expected = true;
    };

    # ── O-DECL-3a: the missing INPUT refuses — and the PAIR is the measurement ──
    # Absence of the declaration INPUT and absence of a KEY's declaration go opposite ways. Read
    # alone either cell is satisfied by a surface that treats all absence alike; together they show
    # the surface discriminates the two.
    test-missing-category-source-refuses = {
      expr = refuses (genDelivery.project { inherit values; });
      expected = true;
    };
    # CONTROL, same call, same run, declaration present: it succeeds.
    test-control-category-source-present-succeeds = {
      expr = refuses (genDelivery.project { inherit values cnf; });
      expected = false;
    };
    # The refusal does not depend on the input having content to classify. An empty registry never
    # reaches the predicate, so a refusal wired at the point of USE would read clean here — which
    # would make it a refusal that fires on the size of the input rather than on the input's
    # absence.
    test-missing-category-source-refuses-on-an-empty-registry = {
      expr = refuses (genDelivery.project { values = { }; });
      expected = true;
    };
  };
}
