# The closed doors' shared checks (den-hoag-7gp66 P1): `project` and `realize` take
# `prelude.checkOptions` over `prelude.checkRequired` rather than native closed formals, which refused
# a missing or unknown field past `tryEval`. Both are MIXED doors, so both stay CLOSED on both axes
# until P2 moves the options off the record: an extra field is an unknown option and is refused, and
# there is no record door here for R5's admitted-extra case. Catchability is asserted here; each
# message is pinned on the real path in `ci/tests-error.nix`.
{ genDelivery, ... }:
let
  # WHNF only: each door forces its check at the call, so the refusal meets the caller there.
  caught = e: (builtins.tryEval e).success;

  validProject = {
    values = { };
    cnf.keySemantics = { };
    selectNodes = _: { };
  };
  validRealize = {
    projected.nodes = { };
    terminals.nixos = args: args;
  };
in
{
  # LIVE CONTROL: `caught` reads `false` on an ordinary throw and `true` on a value, so every
  # `!(caught …)` below is not a helper that reads the same whatever it is handed.
  flake.tests.doors.test-control = {
    expr = {
      throwCaughtAsFailure = caught (throw "control");
      valueSucceeds = caught 1;
    };
    expected = {
      throwCaughtAsFailure = false;
      valueSucceeds = true;
    };
  };

  # `project`: `values` required; `cnf` and `selectNodes` optional.
  flake.tests.doors.test-project = {
    expr = {
      valid = (genDelivery.project validProject).nodes;
      missingRequiredRefused = !(caught (genDelivery.project { cnf.keySemantics = { }; }));
      unknownOptionRefused = !(caught (genDelivery.project (validProject // { notAnOption = 1; })));
      nonSetRefused = !(caught (genDelivery.project 1));
    };
    expected = {
      valid = { };
      missingRequiredRefused = true;
      unknownOptionRefused = true;
      nonSetRefused = true;
    };
  };

  # `realize`: `projected` and `terminals` required; the layer inputs and extras optional.
  flake.tests.doors.test-realize = {
    expr = {
      valid = genDelivery.realize validRealize;
      validWithOptions = genDelivery.realize (
        validRealize
        // {
          bindings = { };
          refinements = { };
          layerOrder = genDelivery.defaultLayerOrder;
          extraModules = { };
        }
      );
      missingRequiredRefused = !(caught (genDelivery.realize { projected.nodes = { }; }));
      unknownOptionRefused = !(caught (genDelivery.realize (validRealize // { notAnOption = 1; })));
      nonSetRefused = !(caught (genDelivery.realize 1));
    };
    expected = {
      valid.nixos = { };
      validWithOptions.nixos = { };
      missingRequiredRefused = true;
      unknownOptionRefused = true;
      nonSetRefused = true;
    };
  };
}
