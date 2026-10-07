# THE CLASS DISCIPLINE — `consume`'s class-discipline half, homed at this surface.
#
# A value reaches class `<to>`'s terminal by exactly two routes, and each is held here:
#
#   IMPLICIT   `modules` — the node's own `<to>` content. A terminal never receives a peer class's
#              content, so an un-adapted class mismatch has no implicit route (C1).
#   EXPLICIT   `extraModules`, ADDRESSED `{ <class>.<node> = [ module ]; }` — a crossing whose target
#              is a declared point of the realization. It arrives at that one terminal at that one
#              node and nowhere else (C2); an address that names no point refuses by name
#              (tests-error.nix, R0–R3). Declared content for a class with no terminal is an
#              address of the implicit route, and refuses the same way (C6, R4).
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

  realizeWith = extraModules: genDelivery.realize { inherit extraModules; } terminals projected;

  implicit = realizeWith { };
  crossed = realizeWith { a.n = adaptBA "n"; };

  # One addressed extra THROWS when forced, and a per-class map with no nodes names a class with no
  # terminal. Neither may be touched by the address check.
  unforced = realizeWith {
    a.n = [ (throw "gen-delivery test: extra module forced") ];
    d = { };
  };

  # A projection that THROWS when forced. The result's own spine reads it — the content check is
  # total over the class sets, so it must — and the positive control below uses it.
  unforceableProjection =
    extraModules:
    genDelivery.realize { inherit extraModules; } terminals {
      nodes = throw "gen-delivery test: projection forced";
    };

  # A projection whose every CONTENT LIST throws when forced. The content check reads each node's
  # class SET, and a class's list only when that class has no terminal — where it refuses anyway —
  # so the result's spine must not reach a list of a class that has one.
  unforceableContent =
    extraModules:
    genDelivery.realize { inherit extraModules; } terminals {
      nodes = builtins.mapAttrs (
        _: nc:
        nc // { classes = builtins.mapAttrs (_: _: throw "gen-delivery test: content forced") nc.classes; }
      ) projected.nodes;
    };

  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;

  # `n` carries d content and nothing realizes d: declared content addressed to no terminal.
  undelivered = {
    n = projected.nodes.n // {
      classes = projected.nodes.n.classes // {
        d = [ { from = "d"; } ];
      };
    };
    inherit (projected.nodes) m;
  };
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

    # ── C6: declared content addressed to a class with no terminal refuses, as its extras do ──
    test-content-for-a-class-with-no-terminal-refuses = {
      expr = forces (genDelivery.realize { } terminals { nodes = undelivered; }).a;
      expected = false;
    };
    # With NO terminal there is no class spine to own the check, so the root owns it.
    test-content-with-an-empty-terminal-set-refuses = {
      expr = forces (genDelivery.realize { } { } { nodes = undelivered; });
      expected = false;
    };
    # THE PLACEMENT: the check sits at the root, not on the class spines. Neither read below forces
    # a class spine — `or` on an absent key and `attrNames` read only the result's own spine — so a
    # check seq'd onto each `realized.<c>` leaves both reading the drop at exit 0.
    test-content-for-a-class-with-no-terminal-refuses-an-or-read = {
      expr = forces ((genDelivery.realize { } terminals { nodes = undelivered; }).d or "absent");
      expected = false;
    };
    test-content-for-a-class-with-no-terminal-refuses-its-class-names = {
      expr = forces (builtins.attrNames (genDelivery.realize { } terminals { nodes = undelivered; }));
      expected = false;
    };
    # POSITIVE CONTROL in the same run — the same instrument over the same terminals, with d's
    # content absent, forces cleanly: the refusal above is d's, not the fixture's.
    test-control-content-with-every-terminal-realizes = {
      expr = forces implicit.a;
      expected = true;
    };

    # ── The result's spine forces no class content ──
    # The result's WHNF reads the projection's node keys and class sets (the content check), and
    # never a content list of a class that has a terminal, nor a terminal.
    test-result-spine-forces-no-class-content = {
      expr = forces (builtins.attrNames (unforceableContent { }));
      expected = true;
    };
    # With an address as well: the node half of the address check stays on the class spine it guards.
    test-result-spine-with-an-address-forces-no-class-content = {
      expr = forces (
        builtins.attrNames (unforceableContent {
          a.n = [ { x = 1; } ];
        })
      );
      expected = true;
    };
    # POSITIVE CONTROL — the lists DO throw when a terminal's modules are forced.
    test-control-a-content-list-throws-when-forced = {
      expr = forces (unforceableContent { }).a.n.modules;
      expected = false;
    };
    # POSITIVE CONTROL — reading a class spine through the same instrument DOES force the projection,
    # so the two cells above are not reading an instrument that cannot see the throw.
    test-control-a-class-spine-forces-the-projection = {
      expr = forces (builtins.attrNames (unforceableProjection { }).a);
      expected = false;
    };
  };
}
