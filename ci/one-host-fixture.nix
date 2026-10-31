# THE ONE-HOST-OF-N FIXTURE (den-hoag-ien5k) — n declared hosts of a `mkInstanceRegistry` kind, each a
# member of aspect `a` (class T content), one terminal `T`. Shared by the fleet-check cells in
# `tests-error.nix` and the cost cells in `tests-process-cells.nix`, which build its arguments from
# raw source. It lives outside ./tests because every file there is a test module.
#
# A plant sits at the LAST host, so a refusal read through `h0` or the class spine is a fleet-wide
# check firing on another node's read:
#   "content"    h<n-1> also reaches `stray` (class U content), and U has no terminal
#   "addressed"  extraModules.T addresses h<n-1>, a member of `none` (no content)
#   "collision"  h<n-1> also reaches `stray`, and its deliveryClasses entry sends U to T
# `members = 3` makes every host a member of `a`, `b` and `c`, where `c` includes `a`.
{
  genDelivery,
  aspects,
  genMerge,
  genSchema,
}:
{
  n,
  plant ? null,
  members ? 1,
}:
let
  t = genMerge.types;
  cnf.keySemantics = {
    T.category = "class";
    U.category = "class";
  };
  hostKinds = genSchema.evalSchema { } [
    {
      config.schema.host.options.aspects = genMerge.mkOption {
        type = t.listOf t.str;
        default = [ ];
      };
    }
  ];
  name = k: "h${toString k}";
  last = name (n - 1);
  base =
    if members == 3 then
      [
        "a"
        "b"
        "c"
      ]
    else
      [ "a" ];
  values =
    (genMerge.evalModuleTree { } [
      ((aspects.mkAspectSchema cnf).mkAspectModule { })
      { options.hosts = genSchema.mkInstanceRegistry { } hostKinds.host; }
      {
        aspects.a.T.marks = [ "a" ];
        aspects.b.T.marks = [ "b" ];
        aspects.c.T.marks = [ "c" ];
        aspects.c.includes = [ "a" ];
        aspects.stray.U.marks = [ "u" ];
        aspects.none.includes = [ ];
        hosts = builtins.listToAttrs (
          builtins.genList (k: {
            name = name k;
            value.aspects =
              if (plant == "content" || plant == "collision") && name k == last then
                base ++ [ "stray" ]
              else if plant == "addressed" && name k == last then
                [ "none" ]
              else
                base;
          }) n
        );
      }
    ]).config;
  projected = genDelivery.project (
    {
      selectNodes = v: v.hosts;
    }
    // (if plant == "collision" then { deliveryClasses.${last}.U = "T"; } else { })
  ) cnf values;
  # A class value is a deferred module: its marks are read through each `imports` layer.
  marksIn =
    m:
    if builtins.isAttrs m then
      (m.marks or [ ]) ++ builtins.concatMap marksIn (m.imports or [ ])
    else
      [ ];
  realized = genDelivery.realize {
    extraModules = if plant == "addressed" then { T.${last} = [ { } ]; } else { };
  } { T = c: builtins.concatMap marksIn c.modules; } projected;
in
{
  # One host's artifact, the class key set, and the membership floor: every host's declared
  # members, nothing projected.
  one = realized.T.h0;
  spine = builtins.attrNames realized.T;
  members = builtins.mapAttrs (_: h: h.aspects) values.hosts;
}
