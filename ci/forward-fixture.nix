# The `forward` fixture, shared by `tests/forward.nix` and `tests-error-forward.nix`.
#
# Invented names only (ADR-0035). A projection is written as CELLS, `{ <node>.<class> = [ [ <id>
# <module> ] ]; }`: each pair is one module of the cell's list and the instance (occurrence) it
# belongs to, which is `project`'s `occurrenceIds`. The receiver is nixpkgs' module system with an
# attrsOf-submodule option `spools` (`shorthandOnlyDefinesConfig = true`, a `lines` and a `str`
# option), so the bytes a target reads are the native merge of the emitted structure.
{ genDelivery, lib }:
let
  inherit (lib) mkOption types;
  cellsToProjected = cells: {
    nodes = builtins.mapAttrs (n: per: {
      bindings.node = {
        name = n;
        shade = "${n}-shade";
      };
      classes = builtins.mapAttrs (_: map (p: builtins.elemAt p 1)) per;
      occurrenceIds = builtins.mapAttrs (_: map builtins.head) per;
      elementIds = builtins.mapAttrs (_: map builtins.head) per;
    }) cells;
  };
  recv = {
    options.spools = mkOption {
      type = types.attrsOf (
        types.submoduleWith {
          shorthandOnlyDefinesConfig = true;
          modules = [
            {
              options.thread = mkOption {
                type = types.lines;
                default = "";
              };
              options.spindle = mkOption {
                type = types.str;
                default = "unset";
              };
            }
          ];
        }
      );
      default = { };
    };
  };
  # The receiver class `c`: every target reads its `spools`, each spool as { thread; spindle; }.
  spoolsOf =
    modules:
    builtins.mapAttrs (_: s: { inherit (s) thread spindle; })
      (lib.evalModules { modules = [ recv ] ++ modules; }).config.spools;
  terminals = {
    c = { modules, ... }: spoolsOf modules;
  };
  # A route. `path` defaults to `spools.<the target node>` (a `dest` segment).
  route =
    {
      name,
      producer ? null,
      order,
      from,
      select ? "declared",
      path ? [
        "spools"
        { dest = "name"; }
      ],
      required ? true,
      site ? "fixture:${name}",
    }:
    {
      inherit
        name
        order
        required
        site
        ;
      producer = if producer == null then from.node else producer;
      from = {
        inherit (from) class node;
        inherit select;
      };
      recipe.importsAt = path;
    };
  occ = node: class: id: { occurrence = { inherit node class id; }; };
  # Forward, then realize with the receiver terminal (and any extra terminals).
  run =
    {
      cells,
      routes ? { },
      unresolved ? [ ],
      extraTerminals ? { },
    }:
    let
      ts = terminals // extraTerminals;
      f = genDelivery.forward { inherit routes unresolved; } ts (cellsToProjected cells);
    in
    f
    // {
      realized = genDelivery.realize { } ts f.projected;
    };
  # The receiver's own content at a target, and the two modules the cells forward.
  own = n: {
    spools.${n} = {
      thread = "R";
      spindle = "receiver";
    };
  };
  mA = {
    thread = "A";
    spindle = lib.mkDefault "group";
  };
  mA' = {
    thread = "A";
  };
  mB = {
    thread = "B";
  };
  t = v: { thread = v; };
  ok = v: (builtins.tryEval (builtins.deepSeq v v)).success;
in
{
  inherit
    cellsToProjected
    terminals
    route
    occ
    run
    own
    mA
    mA'
    mB
    t
    ok
    spoolsOf
    ;
}
