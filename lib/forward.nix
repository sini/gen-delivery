# gen-delivery — `forward`, THE FIRST FORWARDING SLICE (M1 imports-at-path, occurrence relays, the
# explicit whole-cell adapter): `project → forward → realize`.
#
# `forward { routes ? {}; unresolved ? []; } terminals projected → { projected; diagnostics; check; }`
#
# A DATA-ONLY transformation of the projection. It returns the transformed projection, which one
# unchanged `realize` consumes, and beside it two values no target can reach: `diagnostics` (data)
# and `check` (a value that refuses by name when evaluated). Nothing is built and applied later, so
# there is no `mk` constructor. A forward is CONTENT to a delivery class, never extras (ADR-0028
# unamended), and the projection that realizes a delivery class is this library's (ADR-0028), so
# the transformation lives beside `project` and `realize`.
#
# ── THE INPUTS ARE THE LOWER-LEVEL RESOLVED FORM ──
# `routes` is DESTINATION-ADDRESSED and class-major, as `extraModules` is:
# `{ <toClass>.<toNode> = [ route ]; }`, so a one-target read touches its own bucket and the buckets
# upstream of it only. A route is
#   { name; producer; site; order; from = { class; node; select; }; recipe; required ? true; }
#   name, producer  strings; ROUTE IDENTITY is R = (producer, name), stable under a refactor that
#                   keeps the declaration (D5). The bucket is assembled per R, never per local name,
#                   so two producers' same-named routes into one target are two routes.
#   site            where the route was declared; rendered in refusals, never compared.
#   order           the route's DECLARATION ORDER, a list of non-negative ints compared
#                   lexicographically (a declaration position path), supplied by the resolver above
#                   as a total order over the routes it emits per bucket. It is the declaration's own
#                   order (gen-view's `def.order` naming), not an order mark: no rank is supplied as
#                   an argument here. A TIE between two routes into one target refuses by name
#                   (ADR-0029: "a structural tie … is refused by name"). The bucket's list order,
#                   arrival order and traversal order are never read.
#   select          "cell" (W1: the source cell's declared PLUS received occurrences, the explicit
#                   whole-cell adapter), "declared" (W2: declared only, distinct and named), or
#                   { occurrence = { node; class; id; }; } (one occurrence by its source identity L;
#                   when L is not declared at the source cell, the route is an OCCURRENCE RELAY of
#                   what was delivered there).
#   recipe          { importsAt = [ segment ]; } — the M1 family only (D7).
# `unresolved` is `[ { name; producer; site; required ? true; status; reason; } ]`, the routes the
# resolver could not place (status "N" no target, "E" excluded, "R" refused). They need no address.
#
# ── OCCURRENCES ARE A VIEW OF THE PROJECTION ──
# A source cell (class c, node n) exposes its declared contribution as OCCURRENCES: one per
# contributing instance (`project`'s `occurrenceIds`, the element's host: a named aspect, an
# instance vertex), each the ORDERED GROUP of that instance's modules in the cell's list order.
# Inline content belongs to its host's group, so no positional `<iid>/includes/<i>` address is ever
# an occurrence. Source identity L = (node, class, instance id), keyed `toJSON [ n c id ]`: a
# reference tuple of already-minted identities, which mints nothing (ADR-0034, for addressing INSIDE
# this transformation only; an identity that crosses into a receipt key is minted at gkrtw).
# Delivered identity D equals L across a relay and across `importsAt` (placement is destination
# metadata); the slice has no remap, so nothing is re-minted.
#
# ── THE ONE ROUTE DESCRIPTION (D2) ──
# A route r into T selecting at source S has an edge to every route r' into S whose delivery r
# selects: every one for "cell"; none for "declared" or for an occurrence S declares; for a relay of
# L, those routes into S that deliver L. Carriage follows these edges and nothing else, and the
# cycle analysis reads the same edges: a route LIES ON A CYCLE when it is reachable from itself in a
# nonempty path (gen-graph's `selfReachable` construction, a `genericClosure` from the successors);
# a target is AFFECTED when its closure holds a cycle. Two routes in opposite directions carrying
# independent declared occurrences form no edge, so legal two-way exchange is no cycle. Opaque
# evaluation dependencies (a module reading a peer through `extent`) are not routes: nothing here
# claims them.
#
# ── EMISSION: ONE WRAPPER PER TARGET, ARM (a) INSIDE IT ──
# A target (c, n) with a non-empty bucket receives ONE function-form module appended to its own
# class list. Its body imports one function-form module per resolved path,
# `<path> = _: { imports = <groups>; }`, each path's groups in the received order (routes by their
# declaration order; a W1 cell's received occurrences before its declared ones, recursively),
# each path at the position of its first occurrence in that order. Every refusal raised while
# forming them (a cycle, a placement conflict, a duplicate route, a tie, a refusing segment, an
# occurrence the source does not hold) is BODY-PLACED: the list spine reads the bucket's emptiness
# only, so `realize`'s per-class spine never forces a forwarding decision and an unrelated sibling
# stays usable. `forward` adds no module `key`: native dedup is the module system's.
#
# ── CONSUMED CONTENT IS NOT DROPPED CONTENT (C2, arm i) ──
# A class with no terminal realizes nowhere, and `realize` refuses its content by name. Content a
# route selects from such a cell is not dropped, so `forward` STRIPS exactly the consumed declared
# occurrences from it, and a received occurrence there is kept only when no route carries it on.
# Whatever is left refuses through `realize`'s own content check, unchanged. Reading such a cell
# inverts the destination table: it forces every route's `from` and `select` (structure), never a
# group or a module.
{ prelude }:
let
  inherit (builtins)
    attrNames
    concatMap
    concatStringsSep
    elemAt
    filter
    foldl'
    genList
    genericClosure
    groupBy
    head
    isAttrs
    isFunction
    isInt
    isList
    isString
    length
    listToAttrs
    mapAttrs
    toJSON
    tryEval
    typeOf
    ;
  any = builtins.any;
  all = builtins.all;
  imap0 = f: xs: genList (i: f i (elemAt xs i)) (length xs);
  reverse = xs: genList (i: elemAt xs (length xs - 1 - i)) (length xs);
  setAttrByPath = path: value: foldl' (v: k: { ${k} = v; }) value (reverse path);
  # First-appearance unique over strings; `listToAttrs` keeps the FIRST of equal names.
  uniqueOrdered =
    xs:
    let
      first = listToAttrs (
        imap0 (i: x: {
          name = x;
          value = i;
        }) xs
      );
    in
    concatMap (i: if first.${elemAt xs i} == i then [ (elemAt xs i) ] else [ ]) (
      genList (i: i) (length xs)
    );
  lexLess =
    a: b:
    let
      la = length a;
      lb = length b;
      go =
        i:
        if i == la then
          i != lb
        else if i == lb then
          false
        else if elemAt a i == elemAt b i then
          go (i + 1)
        else
          elemAt a i < elemAt b i;
    in
    go 0;
  sortBy = f: builtins.sort (x: y: lexLess (f x) (f y));

  pre = "gen-delivery: forward";
  at = c: n: "${c}.${n}";
  rName = r: "${r.producer}/${r.name}";
  sitesOf = rs: concatStringsSep ", " (map (r: toString (r.site or "<no site>")) rs);

  forwardCore =
    o: terminals: projected:
    let
      routes = o.routes or { };
      unresolved = o.unresolved or [ ];
      nodes = projected.nodes;

      # ── THE ROOT DOORS: names only (the `extraModules` R0 / R2 rule, restated for routes) ──
      _routesCheck =
        if !(isAttrs routes) then
          throw "${pre}: routes must be an attrset, destination-addressed and class-major { <class>.<node> = [ route ]; }, got ${typeOf routes}"
        else if !(isList unresolved) then
          throw "${pre}: unresolved must be a list of { name; producer; site; required; status; reason; }, got ${typeOf unresolved}"
        else
          foldl' (
            acc: c:
            let
              per = routes.${c};
            in
            if !(isAttrs per) then
              throw "${pre}: routes.${c} is not an attrset — routes are CLASS-MAJOR, { <class>.<node> = [ route ]; }"
            else
              foldl' (
                acc': n:
                if !(nodes ? ${n}) then
                  throw "${pre}: routes.${c} addresses node ${n}, which the projection does not carry — the forwarded content would be dropped"
                else
                  acc'
              ) acc (attrNames per)
          ) null (attrNames routes);

      bucketOf =
        c: n:
        let
          b = (routes.${c} or { }).${n} or [ ];
        in
        if isList b then b else throw "${pre}: routes.${c}.${n} must be a list of routes, got ${typeOf b}";

      # ── ONE ROUTE, CHECKED WHERE IT IS READ ──
      checkRoute =
        c: n: r:
        let
          where = "route into ${at c n}";
          bad = msg: throw "${pre}: ${where}: ${msg}";
          sel = r.from.select or null;
        in
        if !(isAttrs r) then
          bad "a route must be an attrset { name; producer; site; order; from; recipe; required; }, got ${typeOf r}"
        else if !(isString (r.name or null)) || !(isString (r.producer or null)) then
          bad "a route names itself by `producer` and `name`, both strings"
        else if !(isList (r.order or null)) || !(all (i: isInt i && i >= 0) r.order) then
          bad "${rName r} must carry `order`, its declaration order, as a list of non-negative ints (the resolver supplies it)"
        else if
          !(isAttrs (r.from or null))
          || !(isString (r.from.class or null))
          || !(isString (r.from.node or null))
        then
          bad "${rName r} must carry `from = { class; node; select; }`"
        else if !(nodes ? ${r.from.node}) then
          bad "${rName r} selects from node ${r.from.node}, which the projection does not carry"
        else if
          !(
            sel == "cell"
            || sel == "declared"
            || (
              isAttrs sel
              && attrNames sel == [ "occurrence" ]
              && isAttrs sel.occurrence
              &&
                attrNames sel.occurrence == [
                  "class"
                  "id"
                  "node"
                ]
              && all isString (builtins.attrValues sel.occurrence)
            )
          )
        then
          bad "${rName r}: `from.select` is \"cell\" (W1, declared plus received), \"declared\" (W2) or { occurrence = { node; class; id; }; }"
        else if
          !(isAttrs (r.recipe or null))
          || attrNames r.recipe != [ "importsAt" ]
          || !(isList r.recipe.importsAt)
        then
          bad "${rName r}: `recipe` is { importsAt = [ segment ]; }, the M1 family only, in this slice"
        else
          r;

      occIdsOf = n: c: ((projected.occurrenceIds or { }).${n} or { }).${c} or null;
      selKind = r: if isAttrs r.from.select then "occurrence" else r.from.select;
      occKey =
        l:
        toJSON [
          l.node
          l.class
          l.id
        ];
      refKey = r: occKey r.from.select.occurrence;

      # ── DECLARED OCCURRENCES OF A SOURCE CELL, read from the INPUT projection ──
      declaredOf = builtins.mapAttrs (
        n: nc: builtins.mapAttrs (c: _: declaredAt c n nc) (nc.classes or { })
      ) nodes;
      declared = c: n: (declaredOf.${n} or { }).${c} or [ ];
      declaredAt =
        c: n: nc:
        let
          mods = nc.classes.${c};
          ids =
            if occIdsOf n c == null then
              throw "${pre}: source cell ${at c n}: the projection carries no `occurrenceIds.${n}.${c}`: occurrences are `project`'s instance attribution, and a projection without it names none"
            else
              projected.occurrenceIds.${n}.${c};
          checkedIds =
            if !(isList ids) || length ids != length mods || !(all isString ids) then
              throw "${pre}: source cell ${at c n}: occurrenceIds.${c} must be one instance id (a string) per module of classes.${c}"
            else
              ids;
          pairs = imap0 (i: id: {
            inherit id;
            m = elemAt mods i;
          }) checkedIds;
          byId = groupBy (p: p.id) pairs;
        in
        map (id: {
          key = occKey {
            node = n;
            class = c;
            inherit id;
          };
          origin = {
            node = n;
            class = c;
            inherit id;
          };
          group = map (p: p.m) byId.${id};
          # The occurrence's immutable captured bindings: its origin node's projection binding.
          captured = nc.bindings or { };
        }) (uniqueOrdered checkedIds);
      declaredKeys = builtins.mapAttrs (
        n: per:
        builtins.mapAttrs (
          c: os:
          listToAttrs (
            map (x: {
              name = x.key;
              value = x;
            }) os
          )
        ) per
      ) declaredOf;
      declaresKey =
        c: n: k:
        ((declaredKeys.${n} or { }).${c} or { }) ? ${k};

      # ── THE ROUTE GRAPH (precise edges, one description for carriage and analysis) ──
      item =
        c: n: r0:
        let
          r = checkRoute c n r0;
        in
        {
          key = toJSON [
            c
            n
            r.producer
            r.name
          ];
          inherit c n r;
        };
      upstream = x: map (item x.r.from.class x.r.from.node) (bucketOf x.r.from.class x.r.from.node);
      kindOf = x: selKind x.r;
      # Does route `u` deliver occurrence `k` into its target? Cycle-safe: a closure over the W1
      # routes upstream of `u`.
      deliversK =
        u: k:
        any
          (
            w:
            let
              kw = kindOf w;
            in
            if kw == "occurrence" then refKey w.r == k else declaresKey w.r.from.class w.r.from.node k
          )
          (genericClosure {
            startSet = [ u ];
            operator = w: if kindOf w == "cell" then upstream w else [ ];
          });
      succ =
        x:
        let
          k = kindOf x;
        in
        if k == "declared" then
          [ ]
        else if k == "cell" then
          upstream x
        else
          let
            key = refKey x.r;
          in
          if declaresKey x.r.from.class x.r.from.node key then
            [ ]
          else
            filter (u: deliversK u key) (upstream x);
      selfReachable =
        x:
        any (y: y.key == x.key) (genericClosure {
          startSet = succ x;
          operator = succ;
        });
      closureOf =
        c: n:
        genericClosure {
          startSet = map (item c n) (bucketOf c n);
          operator = succ;
        };
      # Whether a closure holds a cycle: a depth-first walk, a route met again on the current path.
      hasCycle =
        c: n:
        let
          visit =
            st: v:
            if st.found || st.done ? ${v.key} then
              st
            else if st.path ? ${v.key} then
              st // { found = true; }
            else
              let
                st1 = foldl' visit (
                  st
                  // {
                    path = st.path // {
                      ${v.key} = true;
                    };
                  }
                ) (succ v);
              in
              st1
              // {
                path = st.path;
                done = st1.done // {
                  ${v.key} = true;
                };
              };
        in
        (foldl' visit {
          found = false;
          path = { };
          done = { };
        } (map (item c n) (bucketOf c n))).found;
      cyclicIn = c: n: map (x: "${rName x.r} into ${at x.c x.n}") (filter selfReachable (closureOf c n));

      # ── THE ASSEMBLED BUCKET (D4 per R, then the declared order; a tie refuses) ──
      assembled =
        c: n:
        let
          rs = map (checkRoute c n) (bucketOf c n);
          byR = groupBy (
            r:
            toJSON [
              r.producer
              r.name
            ]
          ) rs;
          dups = filter (k: length byR.${k} > 1) (attrNames byR);
          sorted = sortBy (r: r.order) rs;
          ties =
            if length sorted < 2 then
              [ ]
            else
              filter (i: (elemAt sorted i).order == (elemAt sorted (i + 1)).order) (
                genList (i: i) (length sorted - 1)
              );
        in
        if dups != [ ] then
          let
            d = byR.${head dups};
          in
          throw "${pre}: target ${at c n}: duplicate route ${rName (head d)} (${toString (length d)} declarations: ${sitesOf d})"
        else if ties != [ ] then
          let
            i = head ties;
            a = elemAt sorted i;
            b = elemAt sorted (i + 1);
          in
          throw "${pre}: target ${at c n}: routes ${rName a} and ${rName b} share declaration order ${toJSON a.order}; a structural tie is refused (${
            sitesOf [
              a
              b
            ]
          })"
        else
          sorted;

      # ── PLACEMENT (D1): a finite list of structural segments, concatenation only ──
      resolveSegment =
        env: r: s:
        let
          bad = msg: throw "${pre}: route ${rName r}: placement segment ${msg}";
          walk =
            what: v: p:
            foldl' (
              acc: k: if isAttrs acc && acc ? ${k} then acc.${k} else bad "${what} has no field '${k}'"
            ) v p;
          final = what: v: if isString v then v else bad "${what} is a ${typeOf v}, not a string";
          one =
            src: n: p:
            if !(env.${src} ? ${n}) then
              bad "{ ${src} = \"${n}\"; }: the ${src} bindings have no '${n}'${
                if src == "dest" then " at target ${at env.dest.class env.dest.name}" else ""
              }"
            else
              final "{ ${src} = \"${n}\"; }" (walk "{ ${src} = \"${n}\"; }" env.${src}.${n} p);
          keysOk = ks: builtins.all (k: builtins.elem k ks);
        in
        if isString s then
          s
        else if isFunction s then
          bad "is a function; a placement is structural (no function, conditional or default segment in this slice)"
        else if !(isAttrs s) then
          bad "is a ${typeOf s}; a segment is a string or one of { captured | scope | dest | ref = <name>; path ? [ ]; }"
        else
          let
            ks = attrNames s;
            src = filter (
              k:
              builtins.elem k [
                "captured"
                "scope"
                "dest"
                "ref"
              ]
            ) ks;
            p = s.path or [ ];
          in
          if
            length src != 1
            || !(keysOk ([
              (head src)
              "path"
            ]) ks)
            || !(isString s.${head src})
            || !(isList p)
            || !(all isString p)
          then
            bad "${toJSON ks} is not one of { captured | scope | dest | ref = <name>; path ? [ <name> ]; } (no conditional or default segment in this slice)"
          else if head src == "ref" then
            let
              n = s.ref;
              inC = env.captured ? ${n};
              inS = env.scope ? ${n};
            in
            if inC && inS then
              bad "{ ref = \"${n}\"; } is ambiguous: both the captured and the scope bindings bind '${n}'; address it explicitly"
            else if inC then
              one "captured" n p
            else if inS then
              one "scope" n p
            else
              bad "{ ref = \"${n}\"; }: neither the captured nor the scope bindings bind '${n}'"
          else
            one (head src) s.${head src} p;
      pathOf =
        c: n: r: occ:
        let
          env = {
            captured = occ.captured;
            scope = nodes.${r.from.node}.bindings or { };
            dest = {
              name = n;
              class = c;
            };
          };
        in
        map (resolveSegment env r) r.recipe.importsAt;

      # ── CARRIAGE (an acyclic closure only: an affected target refuses before it gets here) ──
      receivedMemo = mapAttrs (c: per: mapAttrs (n: _: receivedAt c n) per) routes;
      received = c: n: (receivedMemo.${c} or { }).${n} or [ ];
      # The selected set of one route at its source cell, in the cell's order: each occurrence with
      # the placement `sub` it already carries in that cell. A W1 adapter embeds the cell AS IT IS
      # REALIZED THERE, so a received occurrence keeps its arrival path below the route's own; a
      # declared occurrence and an occurrence relay are placed afresh (placement is destination
      # metadata, never identity).
      selected =
        r:
        let
          fc = r.from.class;
          fn = r.from.node;
          k = selKind r;
          fresh = map (occ: {
            inherit occ;
            sub = [ ];
          });
        in
        if k == "declared" then
          fresh (declared fc fn)
        else if k == "cell" then
          map (d: {
            inherit (d) occ;
            sub = d.chunks;
          }) (received fc fn)
          ++ fresh (declared fc fn)
        else
          let
            key = refKey r;
          in
          if declaresKey fc fn key then
            fresh [ ((declaredKeys.${fn}).${fc}).${key} ]
          else
            let
              got = receivedK fc fn key;
            in
            if got == null then
              throw "${pre}: route ${rName r}: selects occurrence ${key}, which source cell ${at fc fn} neither declares nor receives"
            else
              fresh [ got ];
      # An arrival's placement is a list of CHUNKS, one per hop from the target down: the route's own
      # resolved path, then what the occurrence carried in the embedded cell. An empty path adds no
      # structure (content at a cell's root lands at the point the cell is embedded), so it is no
      # chunk.
      arrivals =
        c: n: rs:
        concatMap (
          r:
          map (x: {
            inherit (x) occ;
            inherit r;
            chunks = filter (p: p != [ ]) ([ (pathOf c n r x.occ) ] ++ x.sub);
          }) (selected r)
        ) rs;
      showPath = chunks: concatStringsSep "." (builtins.concatLists chunks);
      # Occurrence-once (T2) after placement consistency (A11): one D at one target at two resolved
      # placements refuses by name; otherwise the first arrival in the declared order stands.
      settle =
        c: n: as:
        let
          byD = groupBy (a: a.occ.key) as;
          conflict = filter (k: length (uniqueOrdered (map (a: toJSON a.chunks) byD.${k})) > 1) (
            attrNames byD
          );
          keys = uniqueOrdered (map (a: a.occ.key) as);
        in
        if conflict != [ ] then
          let
            k = head conflict;
            as' = byD.${k};
          in
          throw "${pre}: occurrence ${k} arrives at target ${at c n} at ${
            toString (length (uniqueOrdered (map (a: toJSON a.chunks) as')))
          } paths (${concatStringsSep ", " (uniqueOrdered (map (a: showPath a.chunks) as'))}; routes ${
            concatStringsSep ", " (map (a: rName a.r) as')
          })"
        else
          map (k: head byD.${k}) keys;
      receivedAt = c: n: settle c n (arrivals c n (assembled c n));
      # One occurrence's arrival at (c, n), following only the routes that deliver it.
      receivedK =
        c: n: k:
        let
          rs = filter (r: deliversK (item c n r) k) (assembled c n);
          as = filter (a: a.occ.key == k) (arrivals c n rs);
        in
        if as == [ ] then null else (head (settle c n as)).occ;

      # ── EMISSION: arm (a) at every hop ──
      # At one level, in the delivered order: an occurrence whose placement ends here contributes its
      # group verbatim and contiguous; the occurrences continuing below one path share ONE
      # function-form module at that path, at the position of the first of them.
      level =
        ds:
        let
          tag = d: if d.chunks == [ ] then "o" + d.occ.key else "p" + toJSON (head d.chunks);
          tags = uniqueOrdered (map tag ds);
          byT = groupBy tag ds;
        in
        concatMap (
          tg:
          let
            its = byT.${tg};
            d0 = head its;
          in
          if d0.chunks == [ ] then
            d0.occ.group
          else
            [
              (setAttrByPath (head d0.chunks) (_: {
                imports = level (map (d: d // { chunks = builtins.tail d.chunks; }) its);
              }))
            ]
        ) tags;

      # ── THE TARGET'S WRAPPER BODY ──
      forwardedModules =
        c: n:
        if hasCycle c n then
          throw "${pre}: target ${at c n} is affected by a forwarding cycle: ${concatStringsSep "; " (cyclicIn c n)} lie on a cycle, and the target receives what they carry"
        else
          level (received c n);
      wrapper = c: n: _: { imports = forwardedModules c n; };

      # ── C2: CONSUMED CONTENT OF A CELL WITH NO TERMINAL ──
      allRoutes = concatMap (c: concatMap (n: map (item c n) (bucketOf c n)) (attrNames routes.${c})) (
        attrNames routes
      );
      consumedBy = groupBy (
        x:
        toJSON [
          x.r.from.class
          x.r.from.node
        ]
      ) allRoutes;
      consumed =
        c: n:
        let
          xs =
            consumedBy.${
              toJSON [
                c
                n
              ]
            } or [ ];
        in
        {
          w1 = any (x: kindOf x == "cell") xs;
          allDeclared = any (
            x:
            builtins.elem (kindOf x) [
              "cell"
              "declared"
            ]
          ) xs;
          keys = listToAttrs (
            map (x: {
              name = refKey x.r;
              value = true;
            }) (filter (x: kindOf x == "occurrence") xs)
          );
        };
      # Every key delivered into (c, n), structurally: a closure over the W1 routes upstream.
      keysInto =
        c: n:
        concatMap
          (
            cell:
            concatMap (
              r:
              let
                k = selKind (checkRoute cell.c cell.n r);
              in
              if k == "occurrence" then [ (refKey r) ] else map (x: x.key) (declared r.from.class r.from.node)
            ) (bucketOf cell.c cell.n)
          )
          (genericClosure {
            startSet = [
              {
                key = toJSON [
                  c
                  n
                ];
                inherit c n;
              }
            ];
            operator =
              cell:
              concatMap (
                r:
                if selKind (checkRoute cell.c cell.n r) == "cell" then
                  [
                    {
                      key = toJSON [
                        r.from.class
                        r.from.node
                      ];
                      c = r.from.class;
                      n = r.from.node;
                    }
                  ]
                else
                  [ ]
              ) (bucketOf cell.c cell.n);
          });
      leftover =
        c: n:
        let
          u = consumed c n;
        in
        if u.w1 then [ ] else filter (k: !(u.keys ? ${k})) (uniqueOrdered (keysInto c n));
      strippedOwn =
        c: n: nc:
        let
          mods = nc.classes.${c};
          u = consumed c n;
          ids = occIdsOf n c;
          keep =
            i:
            !(
              u.allDeclared
              || u.keys
                ? ${
                  occKey {
                    node = n;
                    class = c;
                    id = elemAt ids i;
                  }
                }
            );
          idx = filter keep (genList (i: i) (length mods));
          pick = xs: map (elemAt xs) idx;
        in
        if
          (
            consumedBy
              ? ${
                toJSON [
                  c
                  n
                ]
              }
          ) == false
        then
          null
        else
          builtins.seq (declared c n) {
            classes = pick mods;
            elementIds = if nc ? elementIds && nc.elementIds ? ${c} then pick nc.elementIds.${c} else null;
            occurrenceIds = pick ids;
          };

      # ── THE TRANSFORMED PROJECTION ──
      # Per node: its entry, and its `occurrenceIds` row (the projection's top-level field).
      perNode = mapAttrs (
        n: nc:
        let
          targetClasses = filter (c: isAttrs routes.${c} && routes.${c} ? ${n}) (attrNames routes);
          own = nc.classes or { };
          classNames = uniqueOrdered (attrNames own ++ targetClasses);
          cellOf =
            c:
            let
              hasBucket = bucketOf c n != [ ];
              base =
                if own ? ${c} then
                  {
                    classes = own.${c};
                    elementIds = (nc.elementIds or { }).${c} or null;
                    occurrenceIds = occIdsOf n c;
                  }
                else
                  {
                    classes = [ ];
                    elementIds = [ ];
                    occurrenceIds = [ ];
                  };
              stripped = if terminals ? ${c} || !(own ? ${c}) then null else strippedOwn c n nc;
              b = if stripped == null then base else stripped;
              appendWrapper = if terminals ? ${c} then hasBucket else hasBucket && leftover c n != [ ];
            in
            if appendWrapper then
              {
                classes = b.classes ++ [ (wrapper c n) ];
                elementIds = if b.elementIds == null then null else b.elementIds ++ [ null ];
                occurrenceIds = if b.occurrenceIds == null then null else b.occurrenceIds ++ [ null ];
              }
            else
              b;
          cells = listToAttrs (
            map (c: {
              name = c;
              value = cellOf c;
            }) classNames
          );
          field =
            f:
            listToAttrs (
              concatMap (
                c:
                if cells.${c}.${f} == null then
                  [ ]
                else
                  [
                    {
                      name = c;
                      value = cells.${c}.${f};
                    }
                  ]
              ) classNames
            );
        in
        if targetClasses == [ ] && !(any (c: !(terminals ? ${c})) (attrNames own)) then
          {
            entry = nc;
            occ = (projected.occurrenceIds or { }).${n} or null;
          }
        else
          {
            entry =
              nc
              // {
                classes = mapAttrs (c: _: cells.${c}.classes) cells;
              }
              // (if nc ? elementIds then { elementIds = field "elementIds"; } else { });
            occ = field "occurrenceIds";
          }
      ) nodes;
      nodes' = mapAttrs (n: _: perNode.${n}.entry) nodes;
      occurrenceIds' = mapAttrs (n: _: perNode.${n}.occ) (projected.occurrenceIds or { });

      # ── DIAGNOSTICS (data) AND THE CHECK (a separate value) ──
      unresolvedChecked =
        let
          byR = groupBy (
            u:
            toJSON [
              (u.producer or null)
              (u.name or null)
            ]
          ) unresolved;
          dups = filter (k: length byR.${k} > 1) (attrNames byR);
        in
        if dups != [ ] then
          let
            d = byR.${head dups};
          in
          throw "${pre}: unresolved: duplicate route ${rName (head d)} (${toString (length d)} declarations: ${sitesOf d})"
        else
          map (
            u:
            if
              !(isAttrs u)
              || !(isString (u.name or null))
              || !(isString (u.producer or null))
              || !(builtins.elem (u.status or null) [
                "N"
                "E"
                "R"
              ])
            then
              throw "${pre}: unresolved: each entry is { name; producer; site; required; status = \"N\" | \"E\" | \"R\"; reason; }"
            else
              u // { required = u.required or true; }
          ) unresolved;
      targets = concatMap (
        c: map (n: { inherit c n; }) (filter (n: bucketOf c n != [ ]) (attrNames routes.${c}))
      ) (attrNames routes);
      refusing = filter (
        t:
        !(tryEval (
          builtins.deepSeq (map (d: [
            d.occ.key
            d.chunks
          ]) (if hasCycle t.c t.n then throw "cycle" else received t.c t.n)) true
        )).success
      ) targets;
      diagnostics = {
        cycles = map (x: "${rName x.r} into ${at x.c x.n}") (filter selfReachable allRoutes);
        affected = map (t: at t.c t.n) (filter (t: hasCycle t.c t.n) targets);
        refusing = map (t: at t.c t.n) refusing;
        unresolved = unresolvedChecked;
        unrouted = map rName (filter (u: !u.required && u.status != "R") unresolvedChecked);
        excluded = map (u: {
          route = rName u;
          inherit (u) required;
          reason = u.reason or null;
        }) (filter (u: u.status == "E") unresolvedChecked);
      };
      failing =
        map (
          u:
          "${rName u} (${
            if u.status == "R" then
              "refused"
            else if u.status == "E" then
              "required, excluded"
            else
              "required, no target"
          }: ${toString (u.reason or "no reason given")})"
        ) (filter (u: u.status == "R" || u.required) unresolvedChecked)
        ++ map (r: "${r} (on a forwarding cycle)") diagnostics.cycles
        ++ map (t: "target ${t} refuses its forwarded content (read the target for the reason)") (
          filter (t: !(builtins.elem t diagnostics.affected)) diagnostics.refusing
        );
      check =
        if failing == [ ] then
          true
        else
          throw "${pre}: check: ${toString (length failing)} route(s) fail: ${concatStringsSep "; " failing}";
    in
    builtins.seq _routesCheck {
      projected =
        projected
        // {
          nodes = nodes';
        }
        // (if projected ? occurrenceIds then { occurrenceIds = occurrenceIds'; } else { });
      inherit diagnostics check;
    };
in
{
  forward =
    prelude.door
      {
        name = "gen-delivery.forward";
        optional = [
          "routes"
          "unresolved"
        ];
      }
      (
        o: terminals: projected:
        forwardCore o terminals projected
      );
}
