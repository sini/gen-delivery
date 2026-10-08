# gen-delivery — THE DELIVERY-CLASS REALIZATION SURFACE.
#
# ADR-0028 rules a DELIVERY CLASS: content declared on an aspect, collected per node, and handed to
# a target-owned terminal that turns it into an artifact. This library is the surface that does
# that. It is ONE construct in two halves — the PROJECTION that discovers which keys are delivery
# classes and reshapes the flat aspect registry per node, and the FOLD that calls each class's
# terminal — and they are one because the realization predicate lives in the first half while the
# fold that trusts it lives in the second. Splitting them puts a predicate in one library and its
# only consumer in another.
#
# ── THE SUBSTRATE ARRIVES INJECTED, WHICH IS THE BOUNDARY RULE AND NOT A CONVENIENCE ──
# Only plain data crosses a gen↔gen boundary. This library takes `algebra` and `aspects` as VALUES
# and constructs inside the consumer's own evaluation; it re-exports neither, and in particular it
# republishes no gen-aspects accessor and no algebra constructor under a name of its own. The
# key-category DECLARATION reaches the predicate the same way — as an argument, never as a
# co-resident — which is why this library can read a declaration gen-aspects owns without
# gen-aspects acquiring a delivery-shaped role over the facts it publishes.
#
# `prelude` arrives the same way, and only its door constructor is read: `project` and `realize`
# take their options first, one closed set built with `prelude.door`, and their operands
# positionally after it, the subject last (den-hoag-7gp66 P2). An unknown option is then a refusal
# naming the door that `builtins.tryEval` catches, at the options application itself, where a
# native closed formal aborted past it.
#
# `scope` arrives the same way, as gen-assemble takes it: gen-scope's engine, the one resolution
# calculus, through which `project` runs the receiver-rooted query that certifies each node's walk.
#
# ── AND THE ORDERED FOLD IS NOT WRITTEN HERE ──
# The contribution merge is `algebra.record.foldLayers`: an ordered layer list, least-specific
# first, last wins, no strength lattice, an unknown per-field strategy refused by name. That is
# already the compliant shape for an ordered fold, and it is already built. What this surface writes
# is the LAYER DECLARATION — which layers exist and in what order — and that declaration is its own
# readable artefact rather than a parameter of somebody else's fold. No `strategies` are passed: the
# default is `replace`, which is measured equal to the positional `//` chain this merge has always
# been, so the per-field knob is available and unexercised here.
#
# ── WHAT IS ABOVE THE STACK RATHER THAN A LAYER OF IT ──
# Delivery targets and terminals are framework notions: a configuration framework assembles with
# this surface, and no substrate vocabulary is defined in its terms. That is the `framework` stratum
# on the bucket's own words, and it turns on what the surface DOES — realize delivery targets by
# invoking a caller-supplied terminal — rather than on any name it carries.
#
# ── THE CONTRACT'S NAMES, EACH RESOLVED RATHER THAN PREFERRED ──
# Framework naming never becomes substrate vocabulary, so the three names the dissolving library
# carried are resolved here and not relocated:
#
#   node        was `host`. `node` is ruled substrate vocabulary — a node is a position with
#               attributes and incident labelled edges, of which a registry instance is a VIEW —
#               and the resolved instance under `bindings` is exactly that. `host` is attested in
#               the corpus only in the unrelated DSL-embedding sense ("host language"), so its
#               presence there is not support.
#   extent      was `nodes`, which collided with the ruled term above while meaning something
#               else: the field holds realized ARTIFACTS keyed by node, not nodes. The extent of a
#               predicate is the set of objects of the universe for which it holds (Gelfond &
#               Lifschitz 1988, stable model semantics), and realization is a predicate, so the set
#               of nodes it holds for is that predicate's extent. ★ PRECISELY: the field is NOT the
#               extent — it is an attrset whose SPINE is the extent. Naming a container after its
#               index set is the mirror image of the error being corrected.
#   passthrough was `osConfig`, and it takes no substrate term because none should exist for it.
#               `osConfig` is a nixpkgs/home-manager identifier: framework naming is surface
#               vocabulary at the surface and never substrate vocabulary in a contract, so the fix
#               is to stop pinning one framework's field name here. The contract carries a single
#               TARGET-OWNED passthrough channel, opaque to this surface, of which `osConfig` is one
#               framework's instance named by the consumer. The surface never reads inside it. The
#               name is minted from the ruling's own words and carries no theory citation.
#
#   selectNodes was `selectHosts`, the same substitution as `node` above applied to the formal
#               that selects the node instances; `select` is the verb gen-graph's `selectEdges`
#               already carries.
#
# `modules`, `bindings` and `name` are out of scope for the rename: the first is the module
# system's own vocabulary, the second is already the substrate's relation vocabulary, and the third
# is the member's key rather than a framework term.
{
  algebra,
  aspects,
  prelude,
  scope,
}:
let
  # ── THE DECLARED CONTRIBUTION ORDER ──
  # An ordered list of NAMED contribution layers, least-specific first, folded in declared order.
  # The order is a PARAMETER of the realization and a declaration with a default value — never an
  # implicit one, and never derived from what kind of thing each layer is. A derivation over a
  # kind hierarchy would re-import the topology an ordered fold exists to keep out.
  #
  #   projection  the projection's own binding for the node — `{ node = <resolved instance>; }`.
  #   global      the caller's attrset, applied to every node.
  #   refinement  the caller's per-node entry, `{ <node> = <attrset>; }`.
  #
  # THE THREE ARE SEPARATE INPUTS, and that is a fix rather than a shape. They used to be two: one
  # attrset carrying both the global layer AND the per-node refinements under node-named keys,
  # disambiguated by a runtime `isAttrs` guess. The consequence was admitted in the contract's own
  # header — a node-named refinement key also rode into every node's merged bindings as a literal
  # binding, surprising whenever a formal happened to share a node name. Named layers separate the
  # two namespaces by construction, and an explicit layer list cannot even be written while one
  # layer is nested inside another.
  defaultLayerOrder = [
    "projection"
    "global"
    "refinement"
  ];

  # ── THE REALIZATION PREDICATE ──
  # ADR-0028's Rider: a delivery class realizes only on DECLARED CONTENT, never on structural
  # shape. A key of a flat-registry aspect entry is a delivery class iff BOTH:
  #
  #   1. it is DECLARED `category = "class"`, read through gen-aspects' single classification
  #      surface and never re-derived here; and
  #   2. it CARRIES CONTENT at this entry, read through gen-aspects' `hasClassContent`, the
  #      companion of `keyCategory` over the class VALUE — also never re-derived here (ADR-0012
  #      clause 2). It rejects both spellings of emptiness: `null`, gen-aspects' representable
  #      absence for a declared-but-unset class, and the FABRICATED EMPTY deferredModule
  #      `{ imports = [ ]; }`, the state the Rider's hazard turns on.
  #
  # SHAPE IS NEVER CONSULTED FOR CLASSIFICATION, and that is the whole of the fix. The predicate
  # this replaces asked whether the value was an attrset carrying an `imports` list, which is a
  # shape test wearing content's clothes. It read clean on the contentless arm only because
  # gen-aspects renders a declared-but-unset class as `null` rather than fabricating an empty
  # deferredModule — a representation choice in ANOTHER library, so the Rider was discharged by
  # coincidence and guarded by a tripwire rather than held by construction. And on a second arm it
  # was simply wrong: a key declared `category = "channel"` rides its value VERBATIM, so a channel
  # carrying a module — the cross-framework exchange payload the category exists for — was
  # projected as a delivery class and had its terminal called. A facet declared with a permissive
  # option type does the same. Limb 1 closes both; limb 2 closes the contentless arm independently
  # of how gen-aspects chooses to represent absence.
  deliveryClassesOf =
    cnf: entry:
    builtins.filter (k: aspects.keyCategory cnf k == "class" && aspects.hasClassContent entry.${k}) (
      builtins.attrNames entry
    );

  # THE DECLARATION INPUT'S ABSENCE IS A REFUSAL, and the KEY-level absence is not — the two go
  # opposite ways and collapsing them is the harmful reading. Constructed with no category source
  # this surface has nothing to read a declaration from, and the only thing left to fall back on is
  # the shape test being removed, so it refuses by name. A KEY whose category is `null` is the
  # ordinary, ubiquitous state of a nested aspect — gen-aspects documents `null` as its answer for
  # an unregistered key and a consumer's typo gate is built on exactly that — so an undeclared key
  # is simply not a delivery class and nothing throws. The refusal that IS owed for an unrecognised
  # key IN THE CATEGORY DECLARATION (`cnf`) already exists upstream, at schema construction; an
  # undeclared key in an aspect BODY is outside it: it is a nested aspect, declared by use. A per-key
  # refusal here would throw on every nested aspect in the corpus.
  requireCnf =
    cnf:
    if cnf != null then
      cnf
    else
      throw "gen-delivery: project: no category source — `cnf` is required and has no default. The realization predicate reads the key-category declaration; with none it could only fall back to a structural shape test.";

  # `dedup` — order-preserving unique over a string list, builtins-only (listToAttrs collapses dups).
  dedup =
    xs:
    builtins.attrNames (
      builtins.listToAttrs (
        map (x: {
          name = x;
          value = null;
        }) xs
      )
    );

  # ── THE INCLUDE CLOSURE'S REFUSALS ──
  # Rendered from named bindings, so the `testsError` cells hold each one to its subject. Every one
  # replaces an arm that used to drop something with no message (ADR-0025 item 1).
  memberNotIdentifierRefusal =
    node: k:
    "gen-delivery: project: node '${node}' lists a member that is not an aspect identifier (a "
    + "${builtins.typeOf k}); a member is named by its aspect's key";
  memberUnknownRefusal =
    node: k:
    "gen-delivery: project: node '${node}' names aspect '${k}' as a member, and no aspect has that key";
  # Inline content names its node and then the aspect it was written in (`host`); `at` is the
  # position path from that aspect, the coordinate its author wrote.
  inlineIn = id: host: if id == host then "" else ", inline content of aspect '${host}',";
  foreignIncludeRefusal =
    id: host: at: ref:
    "gen-delivery: project: aspect '${id}'${inlineIn id host} includes at position ${at} a reference into origin "
    + "'${prelude.concatStringsSep "/" ref.origin}', which this tree does not hold; project delivers "
    + "only what it can reach, so federate the trees first";
  # gen-aspects' `sealed` site: an include element that is neither a reference nor inline aspect
  # content. A guard there (inline, or a named guard included by value) has no declaration id, so the
  # producer can mint no instance of it (identity design G5); any other value there (a list, a
  # number, as a fired term can give) is no aspect at all.
  sealedIncludeRefusal =
    id: host: at:
    "gen-delivery: project: aspect '${id}'${inlineIn id host} carries at include position ${at} an element that is "
    + "neither a reference to an aspect nor inline aspect content: a guard there is not a declared "
    + "aspect, so the instance relation can hold no instance of it (declare it as a named aspect and "
    + "include it by key), and any other value (a list, a number) is not an aspect";
  # A reached parametric node is delivered through its instances (ADR-0010 section 4(a)), and is no
  # edge where the relation DECLINED it (its condition resolved FALSE there). A first-order guard the
  # relation neither lists nor declined in a handed scope is undecided there, and refuses.
  undecidedReachRefusal =
    node: id: inst:
    "gen-delivery: project: node '${node}' reaches parametric aspect '${id}'"
    + (if inst == null then "" else " inside instance '${inst}'")
    + ", and the instance relation neither lists an instance of it there nor declined it: either the "
    + "relation never walked it there (it was minted over other members or another tree than project "
    + "reads), or its condition read a coordinate the scope does not supply under the open world "
    + "(declare the coordinate set to make that absence FALSE)";
  noInstanceRefusal =
    node: id: inst:
    "gen-delivery: project: node '${node}' reaches parametric aspect '${id}'"
    + (if inst == null then "" else " inside instance '${inst}'")
    + ", and the instance relation holds no instance of it there; project reads instances, it never mints them";
  edgeVertexRefusal =
    scope: iid:
    "gen-delivery: project: the instance relation's edge from '${scope}' names instance '${iid}', which it holds no vertex for";
  edgeAspectRefusal =
    scope: a: iid:
    "gen-delivery: project: the instance relation's edge from '${scope}' lists instance '${iid}' under aspect '${a}', and it does not instantiate '${a}'";
  # The view's malformed shapes, each read where the walk reads it (htfv3 §2.3's view doors).
  edgesNotAttrsRefusal =
    scope: v:
    "gen-delivery: project: the instance relation's edges from '${scope}' must be an attrset { <aspect> = [ <instance id> ]; }, got ${builtins.typeOf v}";
  edgeListNotListRefusal =
    scope: a: v:
    "gen-delivery: project: the instance relation's edges from '${scope}' under aspect '${a}' must be a list of instance ids, got ${builtins.typeOf v}";
  edgeIdNotStringRefusal =
    scope: a: v:
    "gen-delivery: project: the instance relation's edge from '${scope}' under aspect '${a}' names an instance with a value of type ${builtins.typeOf v}, not an instance id (a string)";
  vertexNotRecordRefusal =
    iid:
    "gen-delivery: project: the instance relation's vertex '${iid}' is not an attrset carrying an attrset `entry`";
  instancesShapeRefusal = "gen-delivery: project: instances must be gen-aspects' instance relation { vertices; instantiates; reaches; nestedAt; declined = { reaches; nestedAt; }; }, each an attrset";
  declinedNotListRefusal =
    scope: v:
    "gen-delivery: project: the instance relation's declined aspects at '${scope}' must be a list of aspect ids, got ${builtins.typeOf v}";
  # The walk derives membership and order; the query certifies that membership by refusal. Both read
  # one materialised projection, so a vertex one holds and the other does not is a relation that
  # lists an edge the declared include sites never walk (first arm), or a vertex the query withholds
  # (second arm; unreachable while `marks` is empty).
  projectionParityRefusal =
    node: v: inQuery:
    "gen-delivery: project: node '${node}' "
    + (
      if inQuery then
        "reaches '${v}' through the instance relation's edges, and its declared include sites never reach it: the relation was minted over other members or another tree than project reads"
      else
        "delivers '${v}' in declared order, and the receiver-rooted query never reaches it"
    );
  # Both sides are named "land in" because the identity side was not sent by any entry.
  deliveryCollisionRefusal =
    node: dc: authored:
    "gen-delivery: project: authored classes ${prelude.concatStringsSep ", " authored} at node "
    + "'${node}' land in one delivery class '${dc}' under deliveryClasses; their contents would merge "
    + "in one terminal";

  # `projectNodes` — the node-keyed reshape of the aspect facts. For each node instance, gather the
  # deferredModules of each class across the INCLUDE CLOSURE of the aspects the node declares
  # membership in (`node.aspects`). `nodes` is the checked result of the caller's `selectNodes`
  # (see `project`). Yields
  #   { <node> = { bindings = { node = <resolved instance>; }; classes = { <delivery class> = [ <deferredModule> ]; };
  #                elementIds = { <delivery class> = [ <id or null> ]; }; }; }
  # PURE — no nixpkgs; the deferredModules stay unforced (opaque) until the terminal imports them.
  #
  # ── WHAT WAS DELIVERED IS NAMED BESIDE IT (den-hoag-htfv3) ──
  # Delivery is a relation, node delivers element, where an element is a named aspect or an instance
  # vertex (ADR-0010 §4(a); ADR-0012: one graph, two node kinds). `classes` is its positional
  # projection onto content and `elementIds` its projection onto identity: both read one list of
  # reached elements (ADR-0012 clause 2, one walk, two materialised views), so their keys and
  # positions agree by construction. A named aspect's id is its facts id, an instance's its vertex id
  # (each fan-out sibling its own), and inline content's its anonymous declaration's (den-hoag-8hlo3):
  # `null` only for inline content that is no node, whose walk key is an address, never a name. One
  # vertex two nodes reach is one id in both lists. `realize` reads neither.
  #
  # ── CONTENT IS COLLECTED BY AUTHORED CLASS AND KEYED BY DELIVERY CLASS ──
  # `deliveryClasses.<node>.<authored class>` names the delivery class that authored class's list
  # is keyed under at that node; an absent entry is the identity. One authored class's list moves
  # whole, in closure order, so the map readdresses content and never reorders or splits it. Two
  # authored classes with content landing in one delivery class would merge in one terminal, so
  # that refuses by name. The refusal reads content, so it sits on the node's `classes` spine (the
  # owner of the merge, as `_addressedNodesCheck` sits on its class's), never on the node entry: a
  # `bindings` read forces no closure.
  #
  # ── THE CLOSURE IS A RECEIVER-ROOTED QUERY, AND gen-aspects STATES ONLY ITS FACTS ──
  # ADR-0010 section 1: a collector is a receiver-rooted query over the aspect graph. It is rooted at
  # the node's members, in declared order, and follows gen-aspects' published `includeSitesOf`
  # breadth-first (`builtins.genericClosure`; the order is a default, reversible):
  #
  #   local    the target node, delivered once however many paths reach it (a diamond is two
  #            edges to one node; an include cycle between named aspects terminates);
  #   content  inline content written at the include position (an aspect literal, or the part
  #            `aspectType` coerces a split definition into), delivered AT ITS POSITION, and its own
  #            sites followed the same way: an anonymous declaration (a site with a `target`) as the
  #            node it is, deduplicated by id; content that is no node by its address;
  #   foreign  refused by name: a reference into a tree this one does not hold;
  #   sealed   refused by name: parametric content with no declaration id.
  #
  # The walk is certified by a second reader of the same facts: gen-scope's `resolve`, rooted at the
  # receiver over one lifted graph per call (`(members | reaches) (includes | nested)*`). Its answer
  # set must equal the walk's delivered vertices, or the node refuses by name. The walk derives;
  # the query certifies.
  #
  # ── A PARAMETRIC NODE IS DELIVERED THROUGH ITS INSTANCES (ADR-0010 §4(a); van Antwerpen 2018 §2.5) ──
  # A guard leaf is never a walk item: its declaration's members exist only where its condition
  # holds, so a static walk through it would deliver them unconditionally. Where it is reached it is
  # replaced by the instances the caller's materialised relation (`instances`, gen-aspects'
  # `instancesFor`) lists at the reaching scope: `reaches.<node>.<id>` for the projected node,
  # `nestedAt.<node>.<iid>.<id>` inside an instance read at that node (den-hoag-8g2rn: a nested
  # include fans out at the meet of its vertex and the reading node, so its edges are per node). An instance item delivers the vertex's `entry` (σ applied
  # per field by the producer) and follows that entry's own `includes`. `instantiates.<iid> == [ id ]`
  # is a well-formedness check that the producer's grouping agrees with the `I` edge; it is not a
  # member resolution. A static node is always walked at node scope, wherever it is reached.
  #
  # THE EMPTY REACH, THREE ARMS (den-hoag-n8wb5). The relation publishes beside its edges the walked
  # guards whose condition was decided FALSE (`declined.reaches.<node>`,
  # `declined.nestedAt.<node>.<iid>`). A
  # reach that lists no instance, in a scope whose edge entry is present:
  #   1. the id is declined there: NO ITEMS. ADR-0019: an includeIf that resolves off is
  #      indistinguishable from an edge that never existed;
  #   2. otherwise, a first-order guard (it has a `condition`): the undecided door. The relation
  #      neither decided it TRUE nor FALSE there: it never walked it (a scope handed without that
  #      member, or a relation over another tree), or the evaluator refused its condition (R: `has`
  #      over a coordinate the scope lacks under the open world, quf7g OQ1);
  #   3. otherwise, and wherever the scope's entry is absent (no `instances`, a node missing from
  #      `reaches`, an instance missing from the node's `nestedAt`) or the id is a guard carrier (it admits every
  #      tuple): the no-instance door.
  # `declined` selects between "no items" and "refuse" and nothing else: it is never folded, counted
  # or ordered, so `project`'s output stays a function of the reached declarations. `project`
  # evaluates no condition.
  #
  # THE CALLER'S OBLIGATION. The relation must be minted over the same `values.aspects` and `cnf`,
  # the same members, the same sources, and the same `containment` (one-step, with its argument
  # bindings) that `project`'s nodes stand for. `project`
  # detects a member the scope omitted and an id the relation's tree never walked (both arm 2), and an
  # edge `reaches.<node>` lists for an aspect the node's include sites never reach (the parity door). It
  # cannot detect (i) a wrong source or containment record, since it never sees either: a FALSE there is
  # genuine for what was handed; (ii) a relation over another tree that walks the same id and decides
  # it FALSE; (iii) for a TRUE reach, a relation over another tree, which delivers that tree's content.
  # An instance id names its declaration and formals, never class content. Under a declared
  # coordinate set, (i) and (ii) deliver nothing at rc 0.
  #
  # A node's walk key is its id, and so is an anonymous declaration's (gen-aspects' facts node for
  # static content, `<iid>/includes/<i>` for an applied body's, den-hoag-8hlo3): inline content is
  # delivered as the node it is. An inline site that is no node (a named element, content past the
  # depth budget) keys `[ anchor ] ++ positionPath`, an ADDRESS into the anchor node's published
  # declaration and never a name for the content: it is generated exactly once (by the one item
  # holding that position), so it never decides a merge, it is rendered only inside a refusal, and
  # it never leaves this function. The classification is gen-aspects'
  # (`resolve`), read here and never re-run. A member is an identifier, resolved through the
  # facts' key→id relation (`nodeIdOf`), never by re-rendering the id.
  projectNodes =
    cnf: deliveryClasses: instances: nodes: values:
    let
      # One facts record per `project` call: each node's sites are a thunk in it, resolved at most
      # once however many nodes reach that node.
      facts = aspects.graphFacts cnf (values.aspects or { });
      # An applied instance body's sites, its anonymous content keyed under the instance id.
      sitesOfInstance = aspects.includeSitesOfInstance cnf (values.aspects or { });
      at = pos: prelude.concatStringsSep "." (map toString pos);

      memberId =
        node: k:
        if !builtins.isString k then
          throw (memberNotIdentifierRefusal node k)
        else
          facts.nodeIdOf.${k} or (throw (memberUnknownRefusal node k));

      # `inst` is the reaching scope: null for the projected node, else the enclosing instance id. An
      # instance item's key is `[ <iid> ]`, a key space distinct from facts ids (`aspect-instance:`).
      nodeItem = id: {
        key = [ id ];
        inherit id;
        pos = [ ];
        inst = null;
      };
      # The instances listed at `(scope, id)`, each checked against the vertex it names and its `I`
      # edge. An empty reach takes THE EMPTY REACH's three arms: declined (in a present edge entry)
      # delivers nothing, a first-order guard (gen-aspects' `termGuard`: it has a `condition`) in a
      # present entry refuses as undecided, and anything else by the no-instance door.
      # The nested edges a node reads are the relation's edges AT that node (gen-aspects `nestedAt`,
      # den-hoag-8g2rn S3c: a nested include fans out at the meet of its vertex and the reading node).
      nestedOf = nodeName: v: instances.nestedAt.${nodeName}.${v} or null;
      instancesAt =
        nodeName: inst: id:
        let
          scope = if inst == null then nodeName else inst;
          edges = if inst == null then instances.reaches.${nodeName} or null else nestedOf nodeName inst;
          ids = if edges == null then null else edges.${id} or null;
          declined =
            if inst == null then
              instances.declined.reaches.${nodeName} or [ ]
            else
              instances.declined.nestedAt.${nodeName}.${inst} or [ ];
        in
        if edges != null && !builtins.isAttrs edges then
          throw (edgesNotAttrsRefusal scope edges)
        else if ids != null && !builtins.isList ids then
          throw (edgeListNotListRefusal scope id ids)
        else if ids == null || ids == [ ] then
          if !builtins.isList declined then
            throw (declinedNotListRefusal scope declined)
          else if edges != null && builtins.elem id declined then
            [ ]
          else if edges != null && facts.nodeData.${id} ? condition then
            throw (undecidedReachRefusal nodeName id inst)
          else
            throw (noInstanceRefusal nodeName id inst)
        else
          map (
            iid:
            let
              v = instances.vertices.${iid};
            in
            if !builtins.isString iid then
              throw (edgeIdNotStringRefusal scope id iid)
            else if !(instances.vertices ? ${iid}) then
              throw (edgeVertexRefusal scope iid)
            else if !(builtins.isAttrs v && builtins.isAttrs (v.entry or null)) then
              throw (vertexNotRecordRefusal iid)
            else if (instances.instantiates.${iid} or null) != [ id ] then
              throw (edgeAspectRefusal scope id iid)
            else
              {
                key = [ iid ];
                id = iid;
                pos = [ ];
                inst = iid;
              }
          ) ids;
      # Every reach of a node routes here: a static node is an item at node scope, a parametric one
      # is its instances at the reaching scope, or a refusal.
      reach =
        nodeName: inst: id:
        if aspects.isGuardLeaf facts.nodeData.${id} then
          instancesAt nodeName inst id
        else
          [ (nodeItem id) ];
      # An item's coordinates. `anchor` is the node (or instance) whose value `pos` indexes into
      # (`contentOf`); `host` is the node or instance its content was written in, and `base` the
      # anchor's include path from there, so a refusal reads the position its author wrote.
      anchorOf = item: item.anchor or item.id;
      hostOf = item: item.host or item.id;
      baseOf = item: item.base or [ ];
      succ =
        nodeName: item:
        builtins.concatLists (
          prelude.imap0
            (
              i: site:
              let
                pos = item.pos ++ [ i ];
                named = if item.id == null then anchorOf item else item.id;
                hostAt = at (baseOf item ++ pos);
              in
              if site.kind == "local" then
                reach nodeName item.inst site.target
              else if site.kind == "content" && site ? target && facts.nodeData ? ${site.target} then
                # A static anonymous declaration is a node: reached, and delivered, as one.
                [
                  (
                    nodeItem site.target
                    // {
                      host = hostOf item;
                      base = baseOf item ++ pos;
                    }
                  )
                ]
              else if site.kind == "content" then
                # An applied body's content (its id instance-relative), or an inline position that is
                # no node (no `target`: a named element, content past the depth budget), which keeps
                # its address and whose own sites refuse where read.
                [
                  {
                    key = if site ? target then [ site.target ] else [ (anchorOf item) ] ++ pos;
                    id = site.target or null;
                    anchor = anchorOf item;
                    host = hostOf item;
                    base = baseOf item;
                    inherit (item) inst;
                    inherit pos;
                    inherit (site) sites;
                  }
                ]
              else if site.kind == "foreign" then
                throw (foreignIncludeRefusal named (hostOf item) hostAt site.ref)
              else
                throw (sealedIncludeRefusal named (hostOf item) hostAt)
            )
            (
              if item.pos != [ ] then
                item.sites
              else if item.inst != null then
                sitesOfInstance item.inst instances.vertices.${item.inst}.entry
              else
                facts.includeSitesOf.${item.id}
            )
        );
      # ── THE ONE GRAPH, LIFTED, AND THE RECEIVER-ROOTED QUERY THAT CERTIFIES THE WALK ──
      # One evaluated `scope` per `project` call, shared by every receiver (gen-bind's crossing
      # adapter set lifts the same way), queried through the one calculus, gen-scope's `resolve`
      # (ADR-0006, ADR-0010 §1). The query does not decide membership: the walk above derives
      # membership and order over the materialised projection, and the query's answer set must equal
      # the walk's vertex set or the node refuses (THE PROJECTION-PARITY DOOR, below).
      # Vertices: each receiver (keyed `toJSON [ <node> ]`, a key space no hash identity enters),
      # each facts node (anonymous declarations included), each instance OCCURRENCE (keyed
      # `toJSON [ <node> <iid> ]`, one per node that reaches the instance), and each applied body's
      # anonymous content (`<iid>/includes/<i>`), shared by the occurrences of its instance. Edges, every one a fact of an earlier stratum:
      #   members  receiver → each member's facts id
      #   reaches  receiver → the occurrence of every instance the relation lists at its scope
      #   includes facts node, occurrence or applied-body content → each local target and each
      #            anonymous declaration at its sites, through inline content that is no node (static
      #            targets; at a facts node also the guard declarations reached at node scope)
      #   nested   occurrence → the occurrences, at its node, of the instances the relation lists
      #            inside it (`nestedAt.<node>.<iid>`)
      # Edges are total over malformed relation shapes: the named doors fire in the ordered fold.
      rid = n: builtins.toJSON [ n ];
      isVertex = v: builtins.isString v && instances.vertices ? ${v};
      localTargets =
        sites:
        builtins.concatMap (
          s:
          if s.kind == "local" || (s.kind == "content" && s ? target) then
            [ s.target ]
          else if s.kind == "content" then
            localTargets s.sites
          else
            [ ]
        ) sites;
      # Every applied body's anonymous content, by id: its sites. Content that is no node holds
      # none below it (gen-aspects keys nothing under a target-less site).
      contentSitesOf = builtins.concatMap (
        s:
        if s.kind == "content" && s ? target then
          [
            {
              name = s.target;
              value = s.sites;
            }
          ]
          ++ contentSitesOf s.sites
        else
          [ ]
      );
      instContent = builtins.listToAttrs (
        builtins.concatMap (
          v: if builtins.isAttrs (entryOf v) then contentSitesOf (sitesOfInstance v (entryOf v)) else [ ]
        ) (builtins.attrNames instances.vertices)
      );
      staticTargets = builtins.filter (
        t: !(facts.nodeData ? ${t} && aspects.isGuardLeaf facts.nodeData.${t})
      );
      listed =
        e:
        if builtins.isAttrs e then
          builtins.concatMap (l: if builtins.isList l then builtins.filter isVertex l else [ ]) (
            builtins.attrValues e
          )
        else
          [ ];
      entryOf = v: instances.vertices.${v}.entry or { };
      instTargets =
        v: if builtins.isAttrs (entryOf v) then localTargets (sitesOfInstance v (entryOf v)) else [ ];
      # ONE shared lift: an instance vertex is lifted once per node that reaches it, as an OCCURRENCE
      # `[ node iid ]`, so the per-node nested edges are edges of one receiver-independent graph and
      # the lift is linear in the occurrences (den-hoag-8g2rn).
      occ =
        n: iid:
        builtins.toJSON [
          n
          iid
        ];
      # Every instance an edge at n names, so an edge always lands on a vertex and a relation listing
      # an instance with no `nestedAt.<n>` entry meets the named doors, never the query's.
      occs = builtins.listToAttrs (
        builtins.concatMap (
          n:
          let
            at = instances.nestedAt.${n} or { };
            inner = if builtins.isAttrs at then at else { };
          in
          map
            (iid: {
              name = occ n iid;
              value = {
                node = n;
                inherit iid;
              };
            })
            (
              builtins.filter isVertex (builtins.attrNames inner)
              ++ listed (instances.reaches.${n} or null)
              ++ builtins.concatMap (i: listed inner.${i}) (builtins.attrNames inner)
            )
        ) (builtins.attrNames nodes)
      );
      lifted =
        scope.eval
          {
            parseParent = _: null;
          }
          {
            children = _: _: { };
            marks = _: _: [ ];
            edges-members =
              _: v:
              if receivers ? ${v} then
                map (memberId receivers.${v}) (nodes.${receivers.${v}}.aspects or [ ])
              else
                [ ];
            edges-reaches =
              _: v:
              if receivers ? ${v} then
                map (occ receivers.${v}) (listed (instances.reaches.${receivers.${v}} or null))
              else
                [ ];
            edges-includes =
              _: v:
              if facts.nodeData ? ${v} then
                (if aspects.isGuardLeaf facts.nodeData.${v} then [ ] else localTargets facts.includeSitesOf.${v})
              else if occs ? ${v} then
                staticTargets (instTargets occs.${v}.iid)
              else if instContent ? ${v} then
                staticTargets (localTargets instContent.${v})
              else
                [ ];
            edges-nested =
              _: v:
              if occs ? ${v} then
                map (occ occs.${v}.node) (listed (nestedOf occs.${v}.node occs.${v}.iid))
              else
                [ ];
          }
          (
            scope.buildRoots {
              parentGraph = scope.vertices (
                builtins.attrNames receivers
                ++ builtins.attrNames facts.nodeData
                ++ builtins.attrNames occs
                ++ builtins.attrNames instContent
              );
            }
          );
      receivers = builtins.listToAttrs (
        map (n: {
          name = rid n;
          value = n;
        }) (builtins.attrNames nodes)
      );
      wf = scope.wellFormed {
        alphabet = [
          "members"
          "reaches"
          "includes"
          "nested"
        ];
        expression = "(members | reaches) (includes | nested)*";
      };
      # The query's answers, read as a SET: nothing below orders over them, so any permutation of
      # `resolve`'s answers gives byte-identical output.
      reachedBy =
        nodeName:
        builtins.listToAttrs (
          map
            (a: {
              name = occs.${a.node}.iid or a.node;
              value = null;
            })
            (scope.resolve {
              inherit wf;
              dataFilter = _: true;
            } lifted (rid nodeName)).answers
        );
      # The entry an item delivers: a node's value or an instance's entry, or the element at the
      # site's position inside its anchor's `includes`, descending through each level's `includes`.
      contentOf =
        item:
        builtins.foldl' (e: i: builtins.elemAt e.includes i) (
          if item.inst != null then instances.vertices.${item.inst}.entry else facts.nodeData.${anchorOf item}
        ) item.pos;
    in
    builtins.mapAttrs (
      nodeName: inst:
      let
        # The walk: membership AND declared order (shortlex over declared positions), over the
        # materialised projection ADR-0019 names as the ordering input. It is permanent: on a lift
        # independent of the receiver, a node-scope instance sits one `reaches` step from the root,
        # so no enumeration of the query's answers places it at its include site.
        walk = builtins.genericClosure {
          startSet = builtins.concatMap (k: reach nodeName null (memberId nodeName k)) (inst.aspects or [ ]);
          operator = succ nodeName;
        };
        inQuery = reachedBy nodeName;
        inFold = builtins.listToAttrs (
          map (i: {
            name = i.id;
            value = null;
          }) (builtins.filter (i: i.id != null) walk)
        );
        delivers =
          v:
          (instances.vertices ? ${v})
          || instContent ? ${v}
          || (facts.nodeData ? ${v} && !(aspects.isGuardLeaf facts.nodeData.${v}));
        # THE PROJECTION-PARITY DOOR: the query certifies the walk's membership by refusal. Guards
        # and inline positions that are no node are not delivered vertices, so neither side counts
        # them; an anonymous declaration is one, so both do.
        _parity =
          let
            extra = builtins.filter (v: delivers v && !(inFold ? ${v})) (builtins.attrNames inQuery);
            missing = builtins.filter (v: !(inQuery ? ${v})) (builtins.attrNames inFold);
          in
          if extra != [ ] then
            throw (projectionParityRefusal nodeName (builtins.head extra) true)
          else if missing != [ ] then
            throw (projectionParityRefusal nodeName (builtins.head missing) false)
          else
            null;
        reached = builtins.seq _parity (
          map (
            item:
            let
              entry = contentOf item;
            in
            {
              inherit entry;
              classes = deliveryClassesOf cnf entry;
              eid = item.id;
            }
          ) walk
        );
        authored = dedup (builtins.concatMap (r: r.classes) reached);
        # Per delivery class: its one authored class and the reached elements carrying it, in
        # closure order. `classes` and `elementIds` are two positional projections of this list.
        delivered = builtins.mapAttrs (
          _: as:
          let
            a = builtins.head as;
          in
          {
            inherit a;
            elements = builtins.filter (r: builtins.elem a r.classes) reached;
          }
        ) groups;
        entryMap = deliveryClasses.${nodeName} or { };
        groups = builtins.groupBy (a: entryMap.${a} or a) authored;
        _collisionCheck = builtins.foldl' (
          acc: dc:
          if builtins.length groups.${dc} > 1 then
            throw (deliveryCollisionRefusal nodeName dc groups.${dc})
          else
            acc
        ) null (builtins.attrNames groups);
      in
      {
        bindings = {
          node = inst;
        };
        classes = builtins.seq _collisionCheck (
          builtins.mapAttrs (_: d: map (r: r.entry.${d.a}) d.elements) delivered
        );
        elementIds = builtins.seq _collisionCheck (
          builtins.mapAttrs (_: d: map (r: r.eid) d.elements) delivered
        );
      }
    ) nodes;

  # `project` — the flat aspect registry plus the per-node build projection. Both keys were
  # published by the dissolving library's compose result; they are this surface's own now.
  #
  # `project { selectNodes ?; deliveryClasses ?; instances ?; } cnf values` (den-hoag-7gp66 P2, rules
  # 2 and 4). The options are one closed set first, a `prelude.door` refused by name and catchably at
  # `project opts`'s own WHNF. `selectNodes` is an option because a caller may omit it — its absence
  # is refused only where the node set is read, so an `aspects`-only caller never supplies it (the
  # criterion at `selector` below). `cnf` is NOT: its absence is refused at the root on every input,
  # so it is a required operand, the configuration the predicate reads, positional and before the
  # values, the subject the surface projects. `project { selectNodes = …; } cnf` is a projection
  # awaiting its values.
  project =
    prelude.door
      {
        name = "gen-delivery.project";
        optional = [
          "selectNodes"
          "deliveryClasses"
          "instances"
        ];
      }
      (
        o: cnf: values:
        projectCore o cnf values
      );

  projectCore =
    o: cnf: values:
    let
      # `values` — the resolved config VALUES of the caller's own evaluation.
      #
      # `cnf` — THE DECLARATION INPUT, the caller's own `mkAspectSchema` argument, arriving BESIDE
      # the values rather than through them. `null` is not a default: it is the absent state, and
      # `requireCnf` refuses it by name. Absence here is a decision, and a defaulted category
      # source would silently degrade the predicate to the shape test being removed.
      #
      # `values → { <node> = instance; }` — names which resolved attrset holds the node instances.
      # `null` is the ABSENT state, not a default. A default here (`v: v.<name> or { }`) bakes a
      # DOMAIN word into this surface and converts a missing registry into a well-typed empty one,
      # which is the vanishing ADR-0035 removes: any registry not spelled `<name>` projected `{ }`
      # with no diagnostic.
      selectNodes = o.selectNodes or null;
      # Forced by the `seq` below rather than only where the predicate reads it. A registry with no
      # member aspects never reaches the predicate at all, so a lazy refusal would let the surface
      # be CONSTRUCTED with no category source and stay silent until some later fixture happened to
      # have content — which is a refusal that fires on the size of the input.
      declaration = requireCnf cnf;
      # Forced where `nodes` is read, NOT under the `seq` below, and that is the criterion the
      # `declaration` comment above states rather than an omission: a refusal must not fire on the
      # SIZE of the input. `cnf` is read only by the predicate, so an empty registry would never
      # reach it — hence the eager force there. `selector`'s absence is independent of every input;
      # it throws iff the formal was omitted, on any `values` whatever, so the criterion is already
      # satisfied at `nodes` and forcing it a level up would only couple an `aspects`-only caller to
      # a node selector it never reads.
      selector =
        if selectNodes != null then
          selectNodes
        else
          throw "gen-delivery: project: no node selector — `selectNodes` is required and has no default. It names WHICH resolved attrset of the caller's values holds the node instances.";
      # `selectNodes` is caller-supplied; a non-attrset result would die inside `mapAttrs` as an
      # anonymous "expected a set" — name the surface, the arg, and the contract instead. Checked
      # HERE, once, so every reader of the node set (the projection and the map's node check below)
      # meets this refusal first and none of them blames its own input for the selector's fault.
      nodes =
        let
          selected = selector values;
        in
        if builtins.isAttrs selected then
          selected
        else
          throw "gen-delivery: project: selectNodes must return an attrset of node instances ({ <node> = <instance>; }), got ${builtins.typeOf selected}";
      # `{ <node> = { <authored class> = <delivery class>; }; }` — the delivery-class map. An absent
      # field is `{ }` and an absent entry the identity, so a caller passing no map projects exactly
      # as before. It is DATA derived from the caller's values, never from this projection's output.
      deliveryClasses = o.deliveryClasses or { };
      # THE MAP'S DOORS, forced at the root beside `declaration` because they read only the map, the
      # declaration and the node set. The node set is read only when the map is non-empty, so an
      # empty map reads neither `values` nor `selectNodes` and nothing here fires on the size of the
      # input. An entry for a class the node has no content for is ACCEPTED: the caller cannot know
      # where content is without reading the projection, which the domain restriction forbids.
      _deliveryClassesCheck =
        if !(builtins.isAttrs deliveryClasses) then
          throw "gen-delivery: project: deliveryClasses must be an attrset { <node> = { <authored class> = <delivery class>; }; }, got ${builtins.typeOf deliveryClasses}"
        else
          builtins.foldl' (
            acc: n:
            let
              e = deliveryClasses.${n};
            in
            if !(builtins.isAttrs e) then
              throw "gen-delivery: project: deliveryClasses.${n} must be an attrset { <authored class> = <delivery class>; }, got ${builtins.typeOf e}"
            else if !(nodes ? ${n}) then
              throw "gen-delivery: project: deliveryClasses names node '${n}', which the projection does not carry; the entry would readdress nothing"
            else
              builtins.foldl' (
                acc': a:
                if aspects.keyCategory declaration a != "class" then
                  throw "gen-delivery: project: deliveryClasses.${n}.${a} readdresses '${a}', which is not declared category \"class\" in cnf"
                else if !(builtins.isString e.${a}) then
                  throw "gen-delivery: project: deliveryClasses.${n}.${a} must be one delivery class name (a string), got ${builtins.typeOf e.${a}}; an authored class is delivered to exactly one delivery class"
                else
                  acc'
              ) acc (builtins.attrNames e)
          ) null (builtins.attrNames deliveryClasses);
      # gen-aspects' instance relation (`instancesFor`), the materialised view the include closure
      # reads a reached parametric node through. An absent field is the empty relation, so a caller
      # passing none meets the no-instance door at every parametric reach. Forced at the root, beside
      # the map: the record is the producer's whole output, so a partial one is refused rather than
      # read as empty. COST: the four fields are forced to WHNF, and gen-aspects forces every pass on
      # any field read, so every `project` call carrying `instances` pays the whole relation, a
      # `bindings` read included.
      instances =
        let
          v =
            o.instances or {
              vertices = { };
              instantiates = { };
              reaches = { };
              nestedAt = { };
              declined = {
                reaches = { };
                nestedAt = { };
              };
            };
        in
        if
          builtins.isAttrs v
          &&
            builtins.attrNames v == [
              "declined"
              "instantiates"
              "nestedAt"
              "reaches"
              "vertices"
            ]
          && builtins.all builtins.isAttrs (builtins.attrValues v)
          &&
            builtins.attrNames v.declined == [
              "nestedAt"
              "reaches"
            ]
          && builtins.all builtins.isAttrs (builtins.attrValues v.declined)
        then
          v
        else
          throw instancesShapeRefusal;
      registry = if values ? aspects then aspects.flatten values.aspects else { };
    in
    builtins.seq declaration (
      builtins.seq _deliveryClassesCheck (
        builtins.seq instances {
          # The FLAT aspect registry (keyed by aspect path): each entry carries its per-class
          # deferredModule fields. The deferredModules are inspectable but unforced, so class bodies
          # cross into a target's evaluation unevaluated. Absent an `aspects` surface, this is empty.
          aspects = registry;

          # The per-node build projection — a node-keyed reshape of the flat registry, driven by each
          # node's `aspects` membership. This is what the terminal builds from.
          nodes = projectNodes declaration deliveryClasses instances nodes values;
        }
      )
    );

  # `realize` — the terminal registry fold. PURE (builtins only, no nixpkgs). It turns a `project`
  # result plus a per-class terminal into class-major artifacts:
  #
  #     realize { bindings ? {}; refinements ? {}; layerOrder ? …; extraModules ? {}; }
  #       terminals projected -> { <class>.<node> = artifact; }
  #
  # For each class that has a terminal, every node whose projection carries a NON-EMPTY module list
  # for that class is realized by calling the terminal with the pinned contract (below). A node with
  # no content for a class does not appear under it — the output is class-major and content-driven.
  # A node carrying content for a class with NO terminal refuses by name: that content is an address
  # naming no point of the realization, and would otherwise be dropped.
  # Each consumed `projected.nodes.<name>` entry MUST carry `bindings` and `classes`, so the bare
  # `nc.bindings` and `.classes` reads below fail loud on a malformed projection rather than papering
  # over it. `classes` is read for every node at the result's WHNF (the content check), so an entry
  # without it fails the whole result.
  #
  # Terminal contract (every field pinned):
  #   name         the node's registry key (string).
  #   modules      `projected.nodes.<name>.classes.<class>` — this class's deferredModule list.
  #                Opaque and unforced; the terminal decides whether/when to evaluate it.
  #   bindings     the contribution layers folded in the DECLARED order (`layerOrder`). There is no
  #                separate `node` field — `bindings.node` IS the resolved instance, contributed by
  #                the projection layer.
  #   extent       the `realized.<class>` set itself — a lazy cross-node accessor for THIS class,
  #                and for this class ONLY: a terminal never receives a peer class's set. Its SPINE
  #                is the class's node keys, so reading the keys forces no peer artifact.
  #   extraModules the extras ADDRESSED to this class at this node (`[]` when absent) — never a
  #                peer class's, by the same rule as `extent`.
  #   passthrough  the TARGET-OWNED channel, present IFF the node's projection entry carries one.
  #                Opaque: this surface never reads inside it, and the keys in it are the
  #                consumer's own (`osConfig` is one framework's instance of one).
  #
  # den-hoag-7gp66 P2, rules 2 and 4: the layer inputs and the extras are one closed options set
  # first, a `prelude.door` refused by name and catchably at `realize opts`'s own WHNF. The terminals
  # are configuration and the projection the subject the fold realizes, so `realize opts terminals`
  # is a realization awaiting its projection.
  realize =
    prelude.door
      {
        name = "gen-delivery.realize";
        optional = [
          "bindings"
          "refinements"
          "layerOrder"
          "extraModules"
        ];
      }
      (
        o: terminals: projected:
        realizeCore o terminals projected
      );

  realizeCore =
    o: terminals: projected:
    let
      # `projected` — a `project` result; only `.nodes` (the per-node build projection) is consumed.
      # `terminals` — `{ <class> = terminal; }`: which classes to realize, and how. The output keys
      # are exactly these class names.
      # THE GLOBAL contribution layer: one attrset applied to every node. It holds bindings and
      # nothing else — a key here named after a node is a binding named after a node, not that
      # node's refinement.
      bindings = o.bindings or { };
      # THE PER-NODE contribution layer: `{ <node> = <attrset>; }`. A separate input from the
      # global layer, which is what keeps the two namespaces apart by construction.
      refinements = o.refinements or { };
      # THE DECLARED ORDER over those layers, least-specific first. A default value, readable and
      # overridable; never an implicit order, and never derived from what kind of thing a layer is.
      layerOrder = o.layerOrder or defaultLayerOrder;
      # `{ <class>.<node> = [ module ]; }` — extras ADDRESSED to one class's terminal at one node,
      # the same coordinate as the output (`[]` when absent). Every address must be a point of the
      # realization or it refuses by name (the checks below). Extras SUPPLEMENT a realization and
      # never create one: they are not declared content (ADR-0028's Rider).
      #
      # ★ DOMAIN RESTRICTION. Forcing the result forces `extraModules`' class names and each
      # per-class map to WHNF, and the spine of `projected.nodes` and each node's class SET (the
      # content check); forcing a class's set `realized.<class>` also forces the class list of each
      # node addressed under that class. An address set — or a projection — DERIVED FROM `realize`'s
      # OWN OUTPUT therefore diverges (uncatchable infinite recursion): a total check must read every
      # address before the realization it guards is observable, so no placement of the check admits
      # it. Derive addresses and projections from the values, never from the realization.
      extraModules = o.extraModules or { };

      nodes = projected.nodes;

      # THE DECLARED ORDER IS TOTAL OVER THE LAYERS, IN BOTH DIRECTIONS. An omitted layer is a
      # DELETED CONTRIBUTION, not a shorter list: drop `projection` and `bindings.node` — which this
      # contract documents as always present — silently vanishes, and the terminal that reads it
      # fails deep inside the target, far from the edit. ADR-0029's precondition is a DECLARED TOTAL
      # order, and one direction guarded is not that. A DUPLICATED layer is refused for the same
      # reason: the fold consumes the list positionally, so the LAST occurrence would decide —
      # silently inverting the declared precedence — and a sequence with duplicates is not an order.
      # Checked once per call and forced at the root, for the same reason the category source is: a
      # realization with no nodes never reaches the per-node fold, so a lazy check would fire on the
      # SIZE of the input.
      _layerOrderCheck =
        let
          sep = builtins.concatStringsSep ", ";
          missing = builtins.filter (l: !(builtins.elem l layerOrder)) defaultLayerOrder;
          unknown = builtins.filter (l: !(builtins.elem l defaultLayerOrder)) layerOrder;
          duplicated = builtins.filter (
            l: builtins.length (builtins.filter (x: x == l) layerOrder) > 1
          ) defaultLayerOrder;
        in
        if missing != [ ] then
          throw "gen-delivery: realize: layerOrder omits contribution layer(s) ${sep missing} — the order is DECLARED and TOTAL over ${sep defaultLayerOrder}, so an omitted layer deletes its contribution"
        else if unknown != [ ] then
          throw "gen-delivery: realize: layerOrder names ${sep unknown}, which is not a contribution layer (declared: ${sep defaultLayerOrder})"
        else if duplicated != [ ] then
          throw "gen-delivery: realize: layerOrder repeats contribution layer(s) ${sep duplicated} — a sequence with duplicates is not an order, and the LAST occurrence would decide, silently inverting the declared precedence"
        else
          null;

      # THE INLET IS ADDRESSED, AND EVERY ADDRESS MUST BE A POINT OF THE REALIZATION. An address that
      # names no point would drop its extras silently, so each one refuses by name instead. The
      # shape and class halves are forced at the root beside `_layerOrderCheck`, for the same reason:
      # they read only `extraModules` and `terminals`. A per-class map with no nodes (`{ d = { }; }`)
      # is no address, so it never refuses.
      _extraModulesCheck = builtins.foldl' (
        acc: className:
        let
          perNode = extraModules.${className};
        in
        if !(builtins.isAttrs perNode) then
          throw "gen-delivery: realize: extraModules.${className} is not an attrset — extraModules is CLASS-MAJOR, { <class>.<node> = [ module ]; }"
        else if perNode != { } && !(terminals ? ${className}) then
          throw "gen-delivery: realize: extraModules.${className}.${builtins.head (builtins.attrNames perNode)} addresses class ${className}, which has no terminal — the extras would be dropped"
        else
          acc
      ) null (builtins.attrNames extraModules);

      # The node half is REFUSED AT ITS OWNER'S LEVEL, on the class spine it guards: reading
      # `realized.<class>` already forces the node keys and every node's list for this class, so the
      # check forces nothing that spine did not, and the result's own spine never reads a class list
      # of a class that has a terminal. Its predicate is the fold's own: `nodes ? <node>` is
      # membership in the key set the fold iterates, and an empty class list is the fold's skip.
      _addressedNodesCheck =
        className:
        builtins.foldl' (
          acc: nodeName:
          if !(nodes ? ${nodeName}) then
            throw "gen-delivery: realize: extraModules.${className} addresses node ${nodeName}, which the projection does not carry — the extras would be dropped"
          else if (nodes.${nodeName}.classes.${className} or [ ]) == [ ] then
            throw "gen-delivery: realize: extraModules.${className}.${nodeName} addresses a node with no declared ${className} content — a delivery class realizes only on declared content, so ${className} does not realize there and the extras would be dropped"
          else
            acc
        ) null (builtins.attrNames (extraModules.${className} or { }));

      # DECLARED CONTENT IS AN ADDRESS TOO, AND IT REFUSES BY THE SAME RULE. A node's non-empty
      # `classes.<c>` addresses class <c>'s terminal exactly as `extraModules.<c>.<node>` does, so a
      # class with content and no terminal refuses by name rather than dropping its content. The
      # predicate is the fold's own: membership in `terminals`, and an empty list is the fold's skip.
      # Forced AT THE ROOT, beside `_extraModulesCheck`, because like R1 it has no owning spine: the
      # class it refuses is exactly the one `realized` never visits, so a spine placement leaves
      # `realized.<c> or …` and `attrNames realized` reading the drop silently. The result's WHNF
      # therefore forces the projection's node keys and each node's class SET; terminal-first, it
      # never reads the list of a class that has a terminal, a content element, or a terminal.
      _contentCheck = builtins.foldl' (
        acc: nodeName:
        builtins.foldl' (
          acc': className:
          if !(terminals ? ${className}) && nodes.${nodeName}.classes.${className} != [ ] then
            throw "gen-delivery: realize: node ${nodeName} carries declared ${className} content, and class ${className} has no terminal — the content would be dropped"
          else
            acc'
        ) acc (builtins.attrNames nodes.${nodeName}.classes)
      ) null (builtins.attrNames nodes);

      # The class-major fold. `realized` is self-referential: a node's `extent` is
      # `realized.<class>`, the same set being built — lazy, so forcing one node's artifact never
      # forces a peer's (the spine is only the class's node keys, populated by `listToAttrs` names).
      # It iterates `terminals`, so it never visits a class with no terminal: `_contentCheck` is what
      # stops such a class's content vanishing here.
      realized = builtins.mapAttrs (
        className: terminal:
        builtins.seq (_addressedNodesCheck className) (
          builtins.listToAttrs (
            builtins.concatMap (
              nodeName:
              let
                nc = nodes.${nodeName};
                classModules = nc.classes.${className} or [ ];
              in
              if classModules == [ ] then
                [ ]
              else
                [
                  {
                    name = nodeName;
                    value =
                      let
                        contributions = {
                          projection = nc.bindings;
                          global = bindings;
                          refinement = refinements.${nodeName} or { };
                        };
                        mergedBindings = algebra.record.foldLayers {
                          layers = map (l: contributions.${l}) layerOrder;
                        };
                      in
                      terminal (
                        {
                          name = nodeName;
                          modules = classModules;
                          bindings = mergedBindings;
                          extent = realized.${className};
                          extraModules = (extraModules.${className} or { }).${nodeName} or [ ];
                        }
                        # The carriage side of the passthrough, renamed. The weld that once tied this
                        # emitted key to the entry's field name is already split, so the target-facing
                        # key a class module reads is derived from nothing here and stays whatever the
                        # consumer put INSIDE the channel.
                        // (if nc ? passthrough then { passthrough = nc.passthrough; } else { })
                      );
                  }
                ]
            ) (builtins.attrNames nodes)
          )
        )
      ) terminals;
    in
    builtins.seq _layerOrderCheck (
      builtins.seq _extraModulesCheck (builtins.seq _contentCheck realized)
    );
in
{
  inherit project realize;

  # The layer declaration, published. An order that ships as a default is only a declaration if a
  # consumer can read it; one that can only be overridden is an implicit order with a hatch.
  inherit defaultLayerOrder;
}
