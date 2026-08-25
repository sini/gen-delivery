# THE EXTENT ACCESSOR — its laziness and its narrowness.
#
# `extent` is the cross-node accessor a terminal reads to reach its peers. Two properties are
# load-bearing and neither is visible from the shape of the result:
#
#   LAZINESS   its SPINE is the class's node keys, so reading the keys forces no peer artifact.
#              Without that the fold is self-referential over forced values and the first read
#              diverges.
#   NARROWNESS a terminal receives the extent of ITS OWN class and never the whole realized set.
#              This is already true of the construction, and it is pinned here so a successor
#              cannot widen it silently — widening is the one thing a governed query surface
#              forbids absolutely, and this accessor is NOT yet on one.
#
# ★ WHAT THIS SUITE DOES NOT CLAIM. `extent` is a raw attrset accessor outside any governed query
# surface: no mark, no narrowing operator, widening trivially expressible by a caller who holds the
# realized set. Routing peer access through governed, narrowable machinery is a construct in its own
# right and is not delivered here. The cells below pin the contract as built; they do not stand in
# for that surface.
{ genDelivery, ... }:
let
  m = { ... }: { };

  entry = name: classes: {
    bindings.node = {
      inherit name;
    };
    inherit classes;
  };

  # `alpha` covers n1 and n2; `beta` covers n2 and n3. The member sets OVERLAP without being equal,
  # so "the extent of its own class" is a claim two different key lists can distinguish — with
  # identical sets the cell would pass under a surface that handed out the whole realized set.
  projected = {
    nodes = {
      n1 = entry "n1" { alpha = [ m ]; };
      n2 = entry "n2" {
        alpha = [ m ];
        beta = [ m ];
      };
      n3 = entry "n3" { beta = [ m ]; };
    };
  };

  # A terminal that reads only the SPINE of its extent. If reading the spine forced a peer
  # artifact, `n2`'s read would force `n1`'s, which would force `n2`'s — the self-reference would
  # not terminate.
  spineTerminal =
    { name, extent, ... }:
    {
      inherit name;
      peers = builtins.sort builtins.lessThan (builtins.attrNames extent);
    };

  spines = genDelivery.realize {
    inherit projected;
    terminals = {
      alpha = spineTerminal;
      beta = spineTerminal;
    };
  };

  # THE POSITIVE CONTROL'S INSTRUMENT: one node's artifact THROWS. A peer that reads only the spine
  # must still evaluate; a peer that forces the artifact must not.
  boomTerminal =
    { name, extent, ... }:
    if name == "n1" then
      throw "gen-delivery test: artifact for `${name}` forced"
    else
      {
        spineOnly = builtins.sort builtins.lessThan (builtins.attrNames extent);
        forcedPeer = extent.n1;
      };

  boomed = genDelivery.realize {
    inherit projected;
    terminals.alpha = boomTerminal;
  };

  forces = v: (builtins.tryEval (builtins.deepSeq v v)).success;
in
{
  flake.tests.extent = {
    # ── O-EXT-1: reading the spine forces no peer artifact ──
    test-reading-the-spine-forces-no-peer-artifact = {
      expr = forces boomed.alpha.n2.spineOnly;
      expected = true;
    };
    # POSITIVE CONTROL in the same run — forcing the peer artifact through the same accessor DOES
    # throw. Without it the clean read above is equally satisfied by an extent with nothing in it.
    test-control-forcing-a-peer-artifact-throws = {
      expr = forces boomed.alpha.n2.forcedPeer;
      expected = false;
    };
    # …and the spine that was read is not empty, so "forces nothing" is not "there was nothing".
    test-control-the-spine-read-is-non-empty = {
      expr = boomed.alpha.n2.spineOnly;
      expected = [
        "n1"
        "n2"
      ];
    };

    # ── O-EXT-2: no widening — the extent is this class's, and only this class's ──
    test-terminal-receives-its-own-classes-extent = {
      expr = spines.alpha.n1.peers;
      expected = [
        "n1"
        "n2"
      ];
    };
    # The peer class, same run, over the same fixture: a DIFFERENT node set. The two lists differ,
    # so the cell above is reading a per-class extent and not the realized set under another name.
    test-control-peer-class-extent-differs = {
      expr = spines.beta.n3.peers;
      expected = [
        "n2"
        "n3"
      ];
    };
    # A peer class's extent is not reachable THROUGH the accessor: its keys are node names, and no
    # class name is among them.
    test-peer-class-is-not-reachable-through-the-extent = {
      expr = builtins.filter (
        k:
        builtins.elem k [
          "alpha"
          "beta"
        ]
      ) (spines.alpha.n2.peers);
      expected = [ ];
    };
    # CONTROL for that absence — the class names ARE the keys of the realized set the accessor is
    # cut from, so the predicate is looking for something that exists one level up.
    test-control-class-names-are-the-realized-sets-keys = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames spines);
      expected = [
        "alpha"
        "beta"
      ];
    };
  };
}
