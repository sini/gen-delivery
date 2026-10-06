# THE RECEIVER-ROOTED QUERY CERTIFIES THE WALK (den-hoag-htfv3-stage-c-graph-query-xm29n).
#
# `project` derives each node's membership and declared order with its walk over the materialised
# projection (the instance relation), and runs gen-scope's `resolve` from the receiver over one
# lifted graph: the answer set must equal the walk's delivered vertices or the node refuses. These
# cells drive `project` through a DOCTORED `scope` whose `resolve` returns rewritten answers, so they
# show the query is read and read as a set. The refusal messages are in `tests-error.nix`
# (S1, an emptied query; S3, an over-listed relation).
{
  genDeliveryWith,
  scope,
  aspects,
  genMerge,
  term,
  ...
}:
let
  # `scope` with `resolve`'s answers passed through `f`.
  answersThrough =
    f:
    scope
    // {
      resolve =
        o: s: from:
        let
          r = scope.resolve o s from;
        in
        r // { answers = f r.answers; };
    };
  fxWith =
    sc:
    import ../parametric-fixture.nix {
      genDelivery = genDeliveryWith sc;
      inherit aspects genMerge term;
    };
  # Every node's realized marks and element ids, under the open and the closed world; a refusing
  # node reads `REFUSED`.
  outputOf =
    fx:
    let
      probe =
        p: n:
        let
          r = builtins.tryEval (
            builtins.deepSeq
              [
                (fx.marksOf p n)
                p.nodes.${n}.elementIds
              ]
              {
                marks = fx.marksOf p n;
                ids = p.nodes.${n}.elementIds;
              }
          );
        in
        if r.success then r.value else "REFUSED";
      perNode = p: builtins.mapAttrs (n: _: probe p n) p.nodes;
    in
    {
      open = perNode fx.withRel;
      closed = perNode fx.withRelCw;
    };
  reverse =
    xs: builtins.genList (i: builtins.elemAt xs (builtins.length xs - 1 - i)) (builtins.length xs);
in
{
  flake.tests.projection-parity = {
    # S2: the answers are read as a SET. Reversed answers give the same output on every node. GREEN
    # on a tree that reads no query too, so it discriminates only "order taken from the answers"
    # (RED: `bf6a04ca…` ≠ `a623aad1…`); S1 is its partner and discriminates "query absent".
    test-permuted-answers-give-the-same-projection = {
      expr = outputOf (fxWith (answersThrough reverse));
      expected = outputOf (fxWith scope);
    };
    # S4: the parametric fixture under both worlds is byte-identical to the walk-only projection
    # (gen-delivery a89dda5, the stage-B view). RED: an over-listed `reaches.na` (S3) reads
    # `5d8fc74d…`. Re-pinned for den-hoag-8g2rn's one containment (`791de44e…` before): every node's
    # output is unchanged except `nhu`'s `hm` id, now minted over its own host's user u3. Re-pinned
    # for den-hoag-8hlo3 (`bb649ac7…` before): the applied body's literal is named, its two
    # `elementIds` entries `null` → `<iid>/includes/0`; with the ids removed both read `4862ef61…`.
    test-projection-equals-the-walk-only-projection = {
      expr = builtins.hashString "sha256" (builtins.toJSON (outputOf (fxWith scope)));
      expected = "034771082a5f349ebde27268273f21230391147c59776ab3de12206a1157a350";
    };
  };
}
