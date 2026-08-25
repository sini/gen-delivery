# THE TERMINAL CONTRACT, observed at the terminal.
#
# `realize` consumes only `projected.hosts`, so the projection here is HAND-BUILT: the cells below
# are about what the fold hands a terminal, and routing them through a real composition would make
# every one of them also a claim about the projection half. The projection half has its own suite.
#
# TWO HOSTS, and the asymmetry is load-bearing rather than decorative: `owned` carries an
# `osConfig` and `plain` does not. The osConfig arm is a CONDITIONAL splice, so a fixture in which
# every host carries one — or none does — never enters one of its two branches.
{ genDelivery, ... }:
let
  m = { ... }: { };

  projected = {
    hosts = {
      plain = {
        bindings = {
          host = {
            name = "plain";
            addr = "10.0.0.1";
          };
        };
        classes.nixos = [ m ];
      };
      owned = {
        bindings = {
          host = {
            name = "owned";
            addr = "10.0.0.2";
          };
        };
        classes.nixos = [ m ];
        osConfig = {
          marker = "target-owned";
        };
      };
    };
  };

  # A reflecting terminal — the carriage is assertable without forcing a class body.
  reflect = args: args;

  realized = genDelivery.realize {
    inherit projected;
    terminals.nixos = reflect;
  };

  carriageKeys = host: builtins.sort builtins.lessThan (builtins.attrNames realized.nixos.${host});
in
{
  flake.tests.carriage = {
    # ── the pinned fields ──
    test-carriage-fields-without-passthrough = {
      expr = carriageKeys "plain";
      expected = [
        "bindings"
        "extraModules"
        "modules"
        "name"
        "nodes"
      ];
    };
    # CONTROL for the row above: the same predicate over the host that DOES carry the target-owned
    # field. Without it, the absence above could be a splice that never fires for anyone.
    test-carriage-fields-with-passthrough = {
      expr = carriageKeys "owned";
      expected = [
        "bindings"
        "extraModules"
        "modules"
        "name"
        "nodes"
        "osConfig"
      ];
    };
    test-passthrough-rides-verbatim = {
      expr = realized.nixos.owned.osConfig;
      expected = {
        marker = "target-owned";
      };
    };

    # ── the projection's own binding reaches the terminal ──
    test-bindings-carry-the-resolved-instance = {
      expr = realized.nixos.plain.bindings.host.addr;
      expected = "10.0.0.1";
    };
    test-name-is-the-registry-key = {
      expr = realized.nixos.owned.name;
      expected = "owned";
    };
    test-extra-modules-default-empty = {
      expr = realized.nixos.plain.extraModules;
      expected = [ ];
    };

    # ── the cross-host accessor ──
    test-peer-accessor-spine = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames realized.nixos.plain.nodes);
      expected = [
        "owned"
        "plain"
      ];
    };
  };
}
