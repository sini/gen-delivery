# THE DECLARED CONTRIBUTION ORDER — the merge is a declaration, not a chain nobody wrote down.
#
# The order used to be a hardcoded positional `//` chain whose only statement anywhere was a gloss
# in a header comment. It was compliant in KIND — ordered, positional, no strength lattice — and
# what it owed was that the order be EXPLICIT. These cells hold it to that: the merged binding set
# is the fold over a DECLARED layer list, and permuting the declaration changes the winner.
#
# The permutation is a permanent pair rather than a one-shot seed. A cell that only asserted "the
# fold produced something" would be satisfied by any merge at all; two orders over one fixture,
# with a key defined in two layers and a key defined in one, is what makes the assertion about the
# ORDER and not about the merging.
{ genDelivery, algebra, ... }:
let
  m = { ... }: { };

  projected = {
    nodes = {
      n1 = {
        bindings.node = {
          name = "n1";
        };
        classes.nixos = [ m ];
      };
      n2 = {
        bindings.node = {
          name = "n2";
        };
        classes.nixos = [ m ];
      };
    };
  };

  # `shared` is defined in BOTH the global and the refinement layer, so the winner is decided by
  # the order alone. `onlyGlobal` is defined in ONE, so its value is order-INVARIANT — which is the
  # blind-cell control: without it, a cell that merely detected "something changed" would pass.
  bindings = {
    shared = "from-global";
    onlyGlobal = "global-only";
  };
  refinements.n1 = {
    shared = "from-refinement";
    onlyRefinement = "refinement-only";
  };

  realizeWith =
    layerOrder:
    genDelivery.realize {
      inherit
        projected
        bindings
        refinements
        layerOrder
        ;
      terminals.nixos = args: args;
    };

  declared = realizeWith genDelivery.defaultLayerOrder;
  # The SAME layers, presented in the opposite specificity order. Nothing else differs.
  permuted = realizeWith [
    "refinement"
    "global"
    "projection"
  ];

  refuses = thunk: !(builtins.tryEval (builtins.deepSeq thunk thunk)).success;
in
{
  flake.tests.contribution-order = {
    # ── the declaration is published and readable ──
    test-default-layer-order-is-published = {
      expr = genDelivery.defaultLayerOrder;
      expected = [
        "projection"
        "global"
        "refinement"
      ];
    };

    # ── O-ORDER-1: the merge equals the fold over the DECLARED layer list ──
    # Stated against the primitive itself rather than against a hand-written expectation, so the
    # cell says "this IS the ordered fold of these layers in this order" and not "these three
    # values came out".
    test-merge-is-the-fold-over-the-declared-layers = {
      expr =
        declared.nixos.n1.bindings == algebra.record.foldLayers {
          layers = [
            projected.nodes.n1.bindings
            bindings
            refinements.n1
          ];
        };
      expected = true;
    };
    # …and the fold agrees with the positional `//` chain this merge has always been, which is what
    # makes adopting the primitive a relocation of the construct rather than a change of behaviour.
    # The chain is written out here in full: an assertion against a reconstruction is only worth the
    # reconstruction being independent of the thing it checks.
    test-fold-agrees-with-the-positional-chain = {
      expr = declared.nixos.n1.bindings == projected.nodes.n1.bindings // bindings // refinements.n1;
      expected = true;
    };
    # CONTROL against a blind cell — the same comparison against a PERMUTED chain is false, so the
    # agreement above discriminates the order rather than holding for any arrangement of the layers.
    test-control-chain-agreement-discriminates-order = {
      expr = declared.nixos.n1.bindings == refinements.n1 // bindings // projected.nodes.n1.bindings;
      expected = false;
    };
    # The winner under the declared order: most specific last.
    test-declared-order-refinement-wins = {
      expr = declared.nixos.n1.bindings.shared;
      expected = "from-refinement";
    };
    # SEEDED DEFECT, kept live: permute the declared order and the winner changes.
    test-permuted-order-changes-the-winner = {
      expr = permuted.nixos.n1.bindings.shared;
      expected = "from-global";
    };
    # CONTROL against a blind cell — a key present in ONE layer only resolves identically under
    # both orders, so the pair above is detecting the ORDER rather than that anything moved.
    test-control-single-layer-key-is-order-invariant = {
      expr = [
        declared.nixos.n1.bindings.onlyGlobal
        permuted.nixos.n1.bindings.onlyGlobal
        declared.nixos.n1.bindings.onlyRefinement
        permuted.nixos.n1.bindings.onlyRefinement
      ];
      expected = [
        "global-only"
        "global-only"
        "refinement-only"
        "refinement-only"
      ];
    };
    # The projection's own contribution is a LAYER like any other, so it loses to a later layer
    # naming the same key — which is what makes the order a parameter rather than a special case.
    test-projection-layer-participates = {
      expr = declared.nixos.n1.bindings ? node;
      expected = true;
    };

    # ── O-ORDER-2: namespace separation, by construction ──
    # A global binding whose name equals a NODE's name is a binding, not that node's refinement.
    # Under the single-attrset shape this fixture was the surprise the old contract admitted in its
    # own header.
    test-global-binding-named-like-a-node-is-not-a-refinement = {
      expr =
        let
          r = genDelivery.realize {
            inherit projected;
            terminals.nixos = args: args;
            bindings.n2 = {
              collide = "global-value-under-a-node-name";
            };
          };
        in
        {
          # n2 does NOT absorb it as a refinement…
          n2HasCollide = r.nixos.n2.bindings ? collide;
          # …and it rides as an ordinary binding, under its own key, for every node.
          n1SeesItAsABinding = r.nixos.n1.bindings.n2;
          n2SeesItAsABinding = r.nixos.n2.bindings.n2;
        };
      expected = {
        n2HasCollide = false;
        n1SeesItAsABinding = {
          collide = "global-value-under-a-node-name";
        };
        n2SeesItAsABinding = {
          collide = "global-value-under-a-node-name";
        };
      };
    };
    # …and the mirror: a refinement key does NOT ride into every node's bindings.
    test-refinement-does-not-ride-into-every-node = {
      expr = [
        (declared.nixos.n1.bindings ? onlyRefinement)
        (declared.nixos.n2.bindings ? onlyRefinement)
        (declared.nixos.n2.bindings ? n1)
      ];
      expected = [
        true
        false
        false
      ];
    };
    # CONTROL — the same shape with a NON-colliding name behaves identically, so the cells above
    # are about the collision and not about refinements working at all.
    test-control-non-colliding-name-behaves-the-same = {
      expr =
        let
          r = genDelivery.realize {
            inherit projected;
            terminals.nixos = args: args;
            bindings.notANode = {
              collide = "global-value-under-a-node-name";
            };
          };
        in
        r.nixos.n1.bindings.notANode == r.nixos.n2.bindings.notANode;
      expected = true;
    };

    # ── the layer names are closed, and an unknown one refuses ──
    test-unknown-layer-refuses = {
      expr =
        refuses
          (realizeWith [
            "projection"
            "kq7wnf3xv"
          ]).nixos.n1.bindings;
      expected = true;
    };
    # CONTROL, same run — a layerOrder naming only declared layers does not refuse.
    test-control-declared-layer-subset-does-not-refuse = {
      expr = refuses (realizeWith [ "projection" ]).nixos.n1.bindings;
      expected = false;
    };
    # A SUBSET is a legitimate declaration: dropping a layer drops its contribution rather than
    # falling back to it.
    test-layer-order-subset-drops-the-omitted-layer = {
      expr = (realizeWith [ "projection" ]).nixos.n1.bindings ? shared;
      expected = false;
    };
  };
}
