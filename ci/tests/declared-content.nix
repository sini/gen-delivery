# THE DECLARED-CONTENT CELLS — ADR-0028's Rider observed at the surface that realizes: a delivery
# class realizes only on DECLARED CONTENT, never on structural shape.
#
# These are the two oracles the dissolving library ran (a contentless class reaches neither the
# projection nor a terminal; a content-given class realizes every member node) re-derived here
# against this surface. They are RE-DERIVED and not transferred: their fixtures name this library's
# own entry points, so no byte-identity transfer was available.
#
# The fixture is a REAL aspect schema resolved through gen-merge, so the class options are rendered
# by gen-aspects itself rather than by hand. What that buys is that "declared but contentless" here
# is the state gen-aspects actually produces; what it cannot buy is the state gen-aspects does NOT
# produce, which is the hazardous one and has its own suite.
{ genDelivery, mkFixture, ... }:
let
  # ONE aspect declaring TWO classes, giving content to exactly one. `metrics` is the axis —
  # declared by the grammar, never set by any definition; `nixos` is the same-shape sibling that IS
  # set, so the two differ on the content axis and on nothing else.
  #
  # TWO hosts, both members of `web` — so "realizes no node" and "realizes EVERY member node" are
  # both claims over a non-empty domain.
  fixture = mkFixture {
    cnf = {
      keySemantics.nixos.category = "class";
      keySemantics.metrics.category = "class";
    };
    modules = [
      {
        config.aspects.web.nixos = { ... }: { };
        config.hosts = {
          h1 = {
            addr = "10.0.4.1";
            aspects = [ "web" ];
          };
          h2 = {
            addr = "10.0.4.2";
            aspects = [ "web" ];
          };
        };
      }
    ];
  };

  projected = genDelivery.project { inherit (fixture) values; };

  # A reflecting terminal — the realized shape is assertable without forcing a class body.
  dataTerminal = { name, ... }: { inherit name; };

  realized = genDelivery.realize {
    inherit projected;
    terminals = {
      nixos = dataTerminal;
      metrics = dataTerminal;
    };
  };

  # A terminal that THROWS on invocation, so "the terminal is never called for a contentless class"
  # is a measurement rather than an inference from the output shape.
  tripwireTerminal = { name, ... }: throw "gen-delivery test: class terminal invoked for `${name}`";

  realizedTripwire = genDelivery.realize {
    inherit projected;
    terminals = {
      nixos = tripwireTerminal;
      metrics = tripwireTerminal;
    };
  };

  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;
in
{
  flake.tests.declared-content = {
    # ── the projection: the contentless class does not reach the per-node projection ──
    # CONTROL — the class is genuinely REGISTERED by the grammar. Without this, the absence below
    # could be an unregistered class, which reads identically.
    test-contentless-class-is-declared = {
      expr = builtins.elem "metrics" (builtins.attrNames projected.aspects.web);
      expected = true;
    };
    # …yet it is absent from the node's class projection, while its content-given sibling is
    # present. The single-element list is the positive half: the projection is live, and `metrics`
    # is missing from a set that has members.
    test-contentless-class-not-projected = {
      expr = builtins.attrNames projected.hosts.h1.classes;
      expected = [ "nixos" ];
    };

    # ── realize: no node realizes under the contentless class ──
    test-contentless-class-realizes-no-node = {
      expr = builtins.attrNames realized.metrics;
      expected = [ ];
    };
    # The class name REMAINS an output key — `realize`'s spine is the caller's `terminals`
    # argument, so key presence is the contract, not a residual of the class having projected.
    test-class-name-remains-an-output-key = {
      expr = builtins.attrNames realized;
      expected = [
        "metrics"
        "nixos"
      ];
    };
    # CONTROL — the content-given class realizes EVERY member node, over the same fixture in the
    # same run.
    test-content-class-realizes-every-member-node = {
      expr = builtins.attrNames realized.nixos;
      expected = [
        "h1"
        "h2"
      ];
    };

    # ── realize: the class terminal is never invoked for the contentless class ──
    test-terminal-never-called-for-contentless-class = {
      expr = forces realizedTripwire.metrics;
      expected = true;
    };
    # CONTROL — the same tripwire, same run, on the content-given class: it DOES fire. So the clean
    # read above is a terminal that was not called, not a tripwire that cannot go off.
    test-tripwire-fires-for-the-content-class = {
      expr = forces realizedTripwire.nixos;
      expected = false;
    };
  };
}
