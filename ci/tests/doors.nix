# THE DOOR CHECKS (den-hoag-7gp66 P2 — `prelude.door`, R7 argument structure / R5 field closure) —
# every published step of gen-delivery that takes a RECORD catches its own violations, at its own
# application, catchably.
#
# Both doors are an OPTIONS step — one closed set, first in the call — then positional operands,
# configuration first and the subject last (spec §p2.3.1, rules 2 and 4):
#   · `project { selectNodes ?; deliveryClasses ?; instances ?; } cnf values` — `cnf` is refused on
#     every input when absent, so it is an operand; `selectNodes` is omittable (its absence refuses
#     only where the node set is read), so it is an option;
#   · `realize { bindings ?; refinements ?; layerOrder ?; extraModules ?; } terminals projected`.
# There is no record step, so no row here carries R5's admitted-extra case or `optionsStep`.
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming each door (R6) live in `ci/tests-error.nix`.
{
  genDelivery,
  mkFixture,
  prelude,
  ...
}:
let
  # `firesAtApplication` forces the step's application to WHNF only — never `deepSeq` — so a check
  # that ran only behind a later field read reads `false` (spec §p2.5, premise 5).
  firesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  # One node `n` with content for class `c` (declared `class`), and one terminal per class.
  fixture = mkFixture {
    cnf.keySemantics.c.category = "class";
    modules = [
      {
        config.aspects.a.c = { ... }: { };
        config.hosts.n = {
          addr = "10.0.0.1";
          aspects = [ "a" ];
        };
      }
    ];
  };
  inherit (fixture) cnf values;
  projected = genDelivery.project { selectNodes = v: v.hosts; } cnf values;
  terminals.c = args: args;

  # The options rows: the door, its options, `apply` supplying the operands after the options step,
  # and one non-default option whose value the door's own result carries (G3), read by `observe`.
  optionsRows = {
    project = {
      optional = [
        "selectNodes"
        "deliveryClasses"
        "instances"
      ];
      apply = f: f cnf values;
      # Without a selector the node set is refused where it is read; with one, it is that node set.
      observe =
        r:
        let
          t = builtins.tryEval (builtins.deepSeq (builtins.attrNames r.nodes) (builtins.attrNames r.nodes));
        in
        if t.success then t.value else "refused: no node selector";
      opt.selectNodes = v: v.hosts;
    };
    realize = {
      optional = [
        "bindings"
        "refinements"
        "layerOrder"
        "extraModules"
      ];
      apply = f: f terminals projected;
      observe = r: builtins.attrNames r.c.n.bindings;
      opt.bindings.global = 1;
    };
  };

  # A field name no door declares, generated per evaluation from the door names themselves, so it is
  # never a name any contract below lists.
  stranger = "not-a-field-of-" + builtins.concatStringsSep "-" (builtins.attrNames optionsRows);

  perOptions = f: builtins.mapAttrs f optionsRows;

  surfaceDoors = builtins.attrNames (
    prelude.filterAttrs (
      _: v:
      let
        t = builtins.tryEval (builtins.isAttrs v && v ? __functor && v ? __contract);
      in
      t.success && t.value
    ) genDelivery
  );
in
{
  flake.tests.doors = {
    # ── LIVE CONTROLS, first: the predicates are not dead ──
    test-control-firesAtApplication-is-true-for-an-ordinary-throw = {
      expr = firesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-firesAtApplication-is-false-for-a-throw-behind-an-unread-field = {
      expr = firesAtApplication { culprit = throw "control probe, not this suite's subject"; };
      expected = false;
    };

    # ── THE TABLE IS THE SURFACE ──
    # Every published door has a row and every row is a published door, so a door added without a
    # row — or a row whose door reverted to a lambda — reds here.
    test-the-door-table-equals-the-surface-doors = {
      expr = surfaceDoors;
      expected = builtins.sort (a: b: a < b) (builtins.attrNames optionsRows);
    };

    # G1/G4: an unknown option is refused at `f opts`'s WHNF, before any operand.
    test-an-unknown-option-is-refused-at-the-options-application = {
      expr = perOptions (n: _: firesAtApplication (genDelivery.${n} { ${stranger} = 1; }));
      expected = perOptions (_: _: true);
    };
    test-a-non-set-options-argument-is-refused-at-the-application = {
      expr = perOptions (n: _: firesAtApplication (genDelivery.${n} 1));
      expected = perOptions (_: _: true);
    };
    # The old one-record shape is refused by name at its first application: its fields are not
    # options of the door.
    test-the-old-one-record-shape-is-refused-at-the-application = {
      expr = {
        project = firesAtApplication (
          genDelivery.project {
            inherit values cnf;
            selectNodes = v: v.hosts;
          }
        );
        realize = firesAtApplication (genDelivery.realize { inherit projected terminals; });
      };
      expected = perOptions (_: _: true);
    };
    # The live control: `{ }` forms the door and the operands answer.
    test-control-the-empty-options-answer = {
      expr = perOptions (n: r: answers (r.observe (r.apply (genDelivery.${n} { }))));
      expected = perOptions (_: _: true);
    };
    # Every option of each door is admitted, together.
    test-every-option-is-admitted = {
      expr = perOptions (
        n: r: !firesAtApplication (genDelivery.${n} (prelude.genAttrs r.optional (_: null)))
      );
      expected = perOptions (_: _: true);
    };
    # D3: the published contract and the functor-aware reader agree with the row.
    test-each-options-door-publishes-its-contract = {
      expr = perOptions (
        n: _: {
          inherit (genDelivery.${n}.__contract) optional open required;
          args = prelude.functionArgs genDelivery.${n};
        }
      );
      expected = perOptions (
        _: r: {
          inherit (r) optional;
          open = false;
          required = [ ];
          args = builtins.listToAttrs (map (f: prelude.nameValuePair f true) r.optional);
        }
      );
    };
    # G3: a non-default option reaches the result (`differ`, against `{ }`), and the partially
    # applied door agrees with the full call (`agree`), each read from its own evaluation.
    test-a-non-default-option-reaches-the-result = {
      expr = perOptions (
        n: r:
        let
          f1 = genDelivery.${n} r.opt;
          run = f: r.observe (r.apply f);
        in
        {
          agree = run f1 == run (genDelivery.${n} r.opt);
          differ = run f1 != run (genDelivery.${n} { });
        }
      );
      expected = perOptions (
        _: _: {
          agree = true;
          differ = true;
        }
      );
    };
    # Composition: `realize opts terminals` is a realization mapped over projections.
    test-a-partially-applied-door-maps-over-projections = {
      expr =
        let
          realizeC = genDelivery.realize { } terminals;
        in
        map (p: builtins.attrNames (realizeC p).c) [
          projected
          (genDelivery.project { selectNodes = _: { }; } cnf { })
        ];
      expected = [
        [ "n" ]
        [ ]
      ];
    };

    # ── THE OPERANDS: `cnf` is required, its absent state refused by name ──
    test-the-project-operands = {
      expr = {
        nullCnfRefused = firesAtApplication (genDelivery.project { } null { });
        nodes = builtins.attrNames projected.nodes;
      };
      expected = {
        nullCnfRefused = true;
        nodes = [ "n" ];
      };
    };
  };
}
