# TWO RECEIVER-ROOTED QUERIES PRODUCE THE ELEMENT LIST (den-hoag-htfv3-stage-c-graph-query-xm29n,
# den-hoag-rdzqb).
#
# `project` runs gen-scope's `resolve` twice per node: the membership query (M) from the receiver
# over one lifted graph, whose answers read as a set are the node's projection, and the order query
# (O) from `toJSON [ ]` over a scope whose vertex set is that projection, whose first-reach answers
# are the element list. These cells drive `project` through a DOCTORED `scope` whose `resolve`
# returns rewritten answers for one of the two, so they show M is read as a set and O as the order.
# The refusal messages are in `tests-error.nix` (S1, an emptied query; S3, an over-listed relation).
{
  genDeliveryWith,
  scope,
  aspects,
  genMerge,
  term,
  ...
}:
let
  # `scope` with the answers of the queries rooted where `p` holds passed through `f`.
  answersAt =
    p: f:
    scope
    // {
      resolve =
        o: s: from:
        let
          r = scope.resolve o s from;
        in
        if p from then r // { answers = f r.answers; } else r;
    };
  isOrderRoot = from: from == builtins.toJSON [ ];
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
    # O2: M's answers are read as a SET. Reversing them gives the same output on every node. GREEN
    # on a tree that reads no query too, so it discriminates only "order taken from M"; O1 is its
    # partner.
    test-permuted-membership-answers-give-the-same-projection = {
      expr = outputOf (fxWith (answersAt (from: !(isOrderRoot from)) reverse));
      expected = outputOf (fxWith scope);
    };
    # O1: O's answers ARE the order. Reversing them reverses `na`'s element ids in every class. RED
    # on a producer that orders by anything but O's answers (the stage-B walk reads them not at all).
    test-reversed-order-answers-reverse-the-delivery = {
      expr = (outputOf (fxWith (answersAt isOrderRoot reverse))).open.na.ids;
      expected = builtins.mapAttrs (_: reverse) (outputOf (fxWith scope)).open.na.ids;
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
