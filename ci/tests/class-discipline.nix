# THE CLASS DISCIPLINE — `consume`'s class-discipline half, homed at this surface.
#
# A value reaches class `<to>`'s terminal by exactly two routes, and each is held here:
#
#   IMPLICIT   `modules` — the node's own `<to>` content. A terminal never receives a peer class's
#              content, so an un-adapted class mismatch has no implicit route (C1).
#   EXPLICIT   `extraModules`, ADDRESSED `{ <class>.<node> = [ module ]; }` — a crossing whose target
#              is a declared point of the realization. It arrives at that one terminal at that one
#              node and nowhere else (C2); an address that names no point refuses by name
#              (tests-error.nix, R0–R3).
#
# ★ WHAT THIS SUITE DOES NOT CLAIM. The inlet is OPAQUE: it cannot tell an adapted module from an
# un-adapted one, so raw `<from>` content addressed to `<to>` IS delivered. Adapter MATCHING is not
# performed here or anywhere; the crossing's adaptation is caller code. What is held is that no
# crossing is IMPLICIT, that an explicit one lands only where it is addressed, and that an address
# which does not realize is refused rather than dropped.
#
# THREE TERMINALS, and the third is load-bearing: with one terminal a class-blind read of the inlet
# delivers to exactly the one class there is, and the arrival cell passes on the broken outcome.
{ genDelivery, ... }:
let
  # `n` carries a, b and c content; `m` carries b only.
  projected.nodes = {
    n = {
      bindings = { };
      classes = {
        a = [ { from = "a"; } ];
        b = [ { from = "b"; } ];
        c = [ { from = "c"; } ];
      };
    };
    m = {
      bindings = { };
      classes.b = [ { from = "b2"; } ];
    };
  };

  # Every terminal reflects its carriage, so what arrived is assertable without forcing a module.
  reflect = args: args;
  terminals = {
    a = reflect;
    b = reflect;
    c = reflect;
  };

  # The consumer's b -> a adapter, applied to the node's own b content: the crossing is caller code.
  adaptBA = node: map (v: { adapted = v; }) projected.nodes.${node}.classes.b;

  realizeWith = extraModules: genDelivery.realize { inherit projected terminals extraModules; };

  implicit = realizeWith { };
  crossed = realizeWith { a.n = adaptBA "n"; };

  # One addressed extra THROWS when forced, and a per-class map with no nodes names a class with no
  # terminal. Neither may be touched by the address check.
  unforced = realizeWith {
    a.n = [ (throw "gen-delivery test: extra module forced") ];
    d = { };
  };

  # A projection that THROWS when forced: the result's own spine is the class names, and it must not
  # reach the projection to produce them.
  unforceableProjection = extraModules: {
    projected.nodes = throw "gen-delivery test: projection forced";
    inherit terminals extraModules;
  };

  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;
in
{
  flake.tests.class-discipline = {
    # ── C1: no implicit crossing — a terminal receives its own class's content only ──
    test-terminal-receives-only-its-own-class-content = {
      expr = {
        a = implicit.a.n.modules;
        b = implicit.b.n.modules;
        c = implicit.c.n.modules;
      };
      expected = {
        a = [ { from = "a"; } ];
        b = [ { from = "b"; } ];
        c = [ { from = "c"; } ];
      };
    };

    # ── C2: the explicit crossing arrives at its address and nowhere else ──
    test-addressed-crossing-arrives-at-its-class = {
      expr = crossed.a.n.extraModules;
      expected = [ { adapted.from = "b"; } ];
    };
    # Absent at the SOURCE class, which a node-keyed inlet would also reach.
    test-addressed-crossing-is-absent-at-the-source-class = {
      expr = crossed.b.n.extraModules;
      expected = [ ];
    };
    # Absent at a BYSTANDER class — the third terminal that makes the arrival cell discriminate.
    test-addressed-crossing-is-absent-at-a-bystander-class = {
      expr = crossed.c.n.extraModules;
      expected = [ ];
    };
    # The crossing supplements the target's own content; it never replaces it.
    test-addressed-crossing-leaves-the-targets-modules-untouched = {
      expr = crossed.a.n.modules;
      expected = [ { from = "a"; } ];
    };

    # ── C5: the address check reads addresses, never modules ──
    test-address-check-forces-no-extra-module = {
      expr = {
        keys = builtins.attrNames unforced.a;
        name = unforced.a.n.name;
        len = builtins.length unforced.a.n.extraModules;
      };
      expected = {
        keys = [ "n" ];
        name = "n";
        len = 1;
      };
    };
    # POSITIVE CONTROL in the same run — the element IS a throw, so the clean read above is the check
    # declining to force it, not a module with nothing in it.
    test-control-the-addressed-extra-throws-when-forced = {
      expr = forces unforced.a.n.extraModules;
      expected = false;
    };

    # ── The result's spine forces no projection ──
    # With no address, the result's WHNF — its class names — reads only `terminals`.
    test-result-spine-forces-no-projection = {
      expr = forces (builtins.attrNames (genDelivery.realize (unforceableProjection { })));
      expected = true;
    };
    # With an address as well: the node half of the check is refused on the class spine it guards,
    # not at the root, so an address does not drag the projection into the result's WHNF.
    test-result-spine-with-an-address-forces-no-projection = {
      expr = forces (
        builtins.attrNames (
          genDelivery.realize (unforceableProjection {
            a.n = [ { x = 1; } ];
          })
        )
      );
      expected = true;
    };
    # POSITIVE CONTROL — reading a class spine through the same instrument DOES force the projection,
    # so the two cells above are not reading an instrument that cannot see the throw.
    test-control-a-class-spine-forces-the-projection = {
      expr = forces (builtins.attrNames (genDelivery.realize (unforceableProjection { })).a);
      expected = false;
    };
  };
}
