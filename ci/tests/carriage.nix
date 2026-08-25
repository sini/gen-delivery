# THE TERMINAL CONTRACT, observed at the terminal.
#
# `realize` consumes only `projected.nodes`, so the projection here is HAND-BUILT: the cells below
# are about what the fold hands a terminal, and routing them through a real composition would make
# every one of them also a claim about the projection half. The projection half has its own suite.
#
# TWO NODES, and the asymmetry is load-bearing rather than decorative: `owned` carries a
# target-owned passthrough and `plain` does not. That channel is a CONDITIONAL splice, so a fixture
# in which every node carries one — or none does — never enters one of its two branches.
#
# ★ THE NAME CELLS HERE ARE SITE-SCOPED BY CONSTRUCTION, WHICH IS THE POINT. They read the key set
# of the carriage the fold actually emits, not tokens in a file. A token-scoped version of the same
# claim goes green by renaming any occurrence of the word anywhere — including uses of `node` that
# are the ruled substrate term used correctly — so it would pass on the broken outcome.
{ genDelivery, ... }:
let
  m = { ... }: { };

  projected = {
    nodes = {
      plain = {
        bindings.node = {
          name = "plain";
          addr = "10.0.0.1";
        };
        classes.nixos = [ m ];
      };
      owned = {
        bindings.node = {
          name = "owned";
          addr = "10.0.0.2";
        };
        classes.nixos = [ m ];
        # The channel's CONTENT is the consumer's own vocabulary. `osConfig` is home-manager's arg
        # name, and it is correct here: framework naming is surface vocabulary AT the surface.
        passthrough.osConfig.marker = "target-owned";
      };
    };
  };

  # A reflecting terminal — the carriage is assertable without forcing a class body.
  reflect = args: args;

  # A per-node extra, supplied for ONE of the two nodes. Until this fixture existed no cell here
  # supplied a non-empty entry, so the per-node routing had no discriminating oracle: a defect that
  # dropped every consumer's extras — a constant `[ ]` in place of the per-node read — left the
  # suite green, because the only value cell asserted the DEFAULT-empty case.
  nodeExtra = {
    config.marker = "per-node-extra";
  };

  realized = genDelivery.realize {
    inherit projected;
    terminals.nixos = reflect;
    extraModules.owned = [ nodeExtra ];
  };

  carriageKeys = node: builtins.sort builtins.lessThan (builtins.attrNames realized.nixos.${node});

  # ── THE ADAPTER MODEL, and why the suite needs one ──
  # A terminal is where the carriage stops and the TARGET's own argument set begins. The two are
  # different contracts, and the whole hazard of this migration is that they used to be welded: one
  # identifier served both, so renaming the substrate-facing side silently renamed the key a class
  # module reads. This models a crossing adapter after the split — carriage in, target args out —
  # so the cells below can ask what the TARGET sees rather than only what the fold emitted.
  adapter =
    {
      extent,
      extraModules,
      modules,
      passthrough ? { },
      ...
    }:
    {
      # The target-facing peer key. `nodes` is what class modules read as `nodes.<peer>.config.…`
      # and it is DERIVED FROM NOTHING on the carriage side — which is exactly what the split
      # bought. The channel splices in under the consumer's own key names.
      specialArgs = {
        nodes = extent;
      }
      // passthrough;
      modules = modules ++ extraModules;
    };

  # THE SWEEP-PRODUCED ADAPTER — the wrong fix, kept in the suite as its own control. This is what
  # a rename that followed the weld produces: the carriage name reaches straight through to the
  # target key.
  weldFollowingAdapter =
    {
      extent,
      extraModules,
      modules,
      passthrough ? { },
      ...
    }:
    {
      specialArgs = {
        inherit extent;
      }
      // passthrough;
      modules = modules ++ extraModules;
    };

  targetArgs = builtins.mapAttrs (_: t: t (realized.nixos.owned)) {
    correct = adapter;
    swept = weldFollowingAdapter;
  };
  specialArgKeys =
    which: builtins.sort builtins.lessThan (builtins.attrNames targetArgs.${which}.specialArgs);
in
{
  flake.tests.carriage = {
    # ── the pinned fields ──
    test-carriage-fields-without-passthrough = {
      expr = carriageKeys "plain";
      expected = [
        "bindings"
        "extent"
        "extraModules"
        "modules"
        "name"
      ];
    };
    # CONTROL for the row above: the same predicate over the node that DOES carry the channel.
    # Without it, the absence above could be a splice that never fires for anyone.
    test-carriage-fields-with-passthrough = {
      expr = carriageKeys "owned";
      expected = [
        "bindings"
        "extent"
        "extraModules"
        "modules"
        "name"
        "passthrough"
      ];
    };
    test-passthrough-rides-verbatim = {
      expr = realized.nixos.owned.passthrough;
      expected = {
        osConfig.marker = "target-owned";
      };
    };
    # THE WELD, SPLIT: the emitted carriage key takes the projection entry's field EXPLICITLY, so
    # the two sides no longer share an identifier. What this pins is the pairing — emitted key to
    # source field — which is exactly what an `inherit` hides.
    test-split-weld-emits-the-entry-field = {
      expr = realized.nixos.owned.passthrough == projected.nodes.owned.passthrough;
      expected = true;
    };
    # CONTROL against a blind cell — the same comparison against a DIFFERENT field of the same
    # entry is false, so the equality above discriminates the pairing rather than matching any two
    # attrsets that happen to be reachable.
    test-control-split-weld-comparison-discriminates = {
      expr = realized.nixos.owned.passthrough == projected.nodes.owned.bindings;
      expected = false;
    };

    # ── THE RENAME, observed at the sites rather than at the tokens ──
    # None of the three framework-named fields survives as a CARRIAGE key. The domain is the emitted
    # key set of both nodes, so this cannot go green by renaming something else in the tree.
    test-no-framework-names-among-carriage-keys = {
      expr = builtins.filter (
        k:
        builtins.elem k [
          "host"
          "nodes"
          "osConfig"
        ]
      ) (carriageKeys "owned" ++ carriageKeys "plain");
      expected = [ ];
    };
    # CONTROL, same predicate, same run — the replacements ARE among those keys. An absence read
    # over a key set that turned out to be empty or unreachable would read identically to this.
    test-control-replacement-names-are-present = {
      expr = builtins.filter (
        k:
        builtins.elem k [
          "extent"
          "passthrough"
        ]
      ) (carriageKeys "owned");
      expected = [
        "extent"
        "passthrough"
      ];
    };
    # The projection's own binding names the resolved instance under the ruled substrate term.
    test-bindings-carry-the-resolved-instance-as-node = {
      expr = realized.nixos.plain.bindings.node.addr;
      expected = "10.0.0.1";
    };
    test-control-bindings-carry-no-host-key = {
      expr = realized.nixos.plain.bindings ? host;
      expected = false;
    };

    # ── THE TARGET-FACING KEY SURVIVED — the cell that catches the wrong fix ──
    # After the rename, an adapter built on the SPLIT weld still hands its target `nodes`. Without
    # this cell the correct migration and the sweep-produced one look identical from the carriage
    # side, because the carriage is renamed in both.
    test-target-facing-peer-key-survives-the-rename = {
      expr = specialArgKeys "correct";
      expected = [
        "nodes"
        "osConfig"
      ];
    };
    # THE SEEDED DEFECT, kept live rather than performed once: the adapter that renamed THROUGH the
    # weld hands its target `extent`, and every class module reading `nodes.<peer>` breaks inside
    # the target's own evaluation. The two key sets differ, so the cell above is discriminating.
    test-control-weld-following-adapter-loses-the-target-key = {
      expr = specialArgKeys "swept";
      expected = [
        "extent"
        "osConfig"
      ];
    };
    # The consumer's own channel key reaches the target under ITS name, not under one this surface
    # chose — which is the whole content of "target-owned".
    test-passthrough-key-is-the-consumers-own = {
      expr = targetArgs.correct.specialArgs.osConfig.marker;
      expected = "target-owned";
    };

    # ── the remaining pinned fields ──
    test-name-is-the-registry-key = {
      expr = realized.nixos.owned.name;
      expected = "owned";
    };
    # ── the per-node extras ROUTE, and the pair is what measures it ──
    # The node the entry names receives it…
    test-extra-modules-reach-the-node-they-are-keyed-under = {
      expr = realized.nixos.owned.extraModules == [ nodeExtra ];
      expected = true;
    };
    # …and the node without an entry gets the default, in the same run. Read alone either row is
    # satisfied by a constant: the first by handing every node every extra, the second by handing
    # no node anything. Together they pin the routing.
    test-extra-modules-default-empty = {
      expr = realized.nixos.plain.extraModules;
      expected = [ ];
    };
    test-extent-spine-is-the-classes-node-keys = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames realized.nixos.plain.extent);
      expected = [
        "owned"
        "plain"
      ];
    };
  };
}
