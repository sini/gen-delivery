# THE DELIVERY-CLASS MAP — `project`'s `deliveryClasses` keys a node's authored-class content under
# the delivery class the caller names for that node, so one authored class realizes on several
# terminals (one per pin) out of one projection.
#
# Each cell reads REALIZED values through a terminal that stamps its own pin and its extent's spine,
# so a cell distinguishes WHICH terminal a node reached and WHICH peers that terminal sees. A cell
# that asserted only the class names would pass on a map that moved the key and dropped the content.
#
# Every refusal's MESSAGE is pinned in `ci/tests-error.nix`; this suite holds the values and the one
# laziness property.
{
  genDelivery,
  aspects,
  genMerge,
  ...
}:
let
  t = genMerge.types;
  cnf.keySemantics = {
    T.category = "class";
    U.category = "class";
  };

  values =
    members:
    (genMerge.evalModuleTree {
      modules = [
        ((aspects.mkAspectSchema cnf).mkAspectModule { })
        {
          options.hosts = genMerge.mkOption {
            type = t.attrsOf t.raw;
            default = { };
          };
        }
        {
          aspects.web.T.marks = [ "web" ];
          aspects.extra.U.marks = [ "u" ];
          aspects.p =
            { host, ... }:
            {
              T.marks = [ host.name ];
            };
          hosts = builtins.mapAttrs (_: m: { aspects = m; }) members;
        }
      ];
    }).config;

  staticMembers = {
    a = [ "web" ];
    b = [ "web" ];
    c = [ "web" ];
  };
  pinMap = {
    a.T = "T1";
    b.T = "T1";
    c.T = "T2";
  };

  projectWith =
    members: extra:
    genDelivery.project (
      {
        values = values members;
        inherit cnf;
        selectNodes = v: v.hosts;
      }
      // extra
    );

  # Each delivery class's terminal stamps its own pin, so the value says which terminal ran.
  term =
    pin:
    { modules, extent, ... }:
    {
      inherit pin;
      marks =
        (genMerge.evalModuleTree {
          modules = [ { freeformType = t.lazyAttrsOf t.anything; } ] ++ modules;
        }).config.marks;
      peers = builtins.attrNames extent;
    };
  realizeWith =
    terminals: members: extra:
    genDelivery.realize {
      projected = projectWith members extra;
      inherit terminals;
    };
  pinned = realizeWith {
    T1 = term "p1";
    T2 = term "p2";
  };

  realizes = e: (builtins.tryEval (builtins.deepSeq e e)).success;

  stamp = pin: peers: {
    inherit pin peers;
    marks = [ "web" ];
  };
  pinSplit = {
    T1 = {
      a = stamp "p1" [
        "a"
        "b"
      ];
      b = stamp "p1" [
        "a"
        "b"
      ];
    };
    T2.c = stamp "p2" [ "c" ];
  };
in
{
  flake.tests.delivery-classes = {
    # ── M1: one authored class, two delivery classes, one projection ──
    # a and b go to T1 (pin p1) and see only each other; c goes to T2 (pin p2) and sees only itself.
    test-the-map-splits-one-authored-class-across-pins = {
      expr = pinned staticMembers { deliveryClasses = pinMap; };
      expected = pinSplit;
    };

    # ── M2: an absent map, and an absent entry, are the identity ──
    # With no map the content stays under its authored class T; an explicit identity map and an
    # empty map project the same.
    test-an-absent-map-is-the-identity = {
      expr =
        let
          r = realizeWith { T = term "T"; } staticMembers;
        in
        {
          absent = r { };
          empty = r { deliveryClasses = { }; } == r { };
          explicitIdentity = r { deliveryClasses.a.T = "T"; } == r { };
        };
      expected = {
        absent.T = {
          a = stamp "T" [
            "a"
            "b"
            "c"
          ];
          b = stamp "T" [
            "a"
            "b"
            "c"
          ];
          c = stamp "T" [
            "a"
            "b"
            "c"
          ];
        };
        empty = true;
        explicitIdentity = true;
      };
    };

    # ── M3: an entry addressing no content is accepted, and changes nothing ──
    # b has no U content, so `b.U` is dead. And at b a map sending T and U to one delivery class
    # merges nothing, because only T carries content: the collision refusal reads content.
    test-a-dead-entry-is-accepted-and-changes-nothing = {
      expr = {
        deadToOtherClass = pinned staticMembers {
          deliveryClasses = pinMap // {
            b = {
              T = "T1";
              U = "T2";
            };
          };
        };
        deadToSameClass = pinned staticMembers {
          deliveryClasses = pinMap // {
            b = {
              T = "T1";
              U = "T1";
            };
          };
        };
      };
      expected = {
        deadToOtherClass = pinSplit;
        deadToSameClass = pinSplit;
      };
    };

    # ── THE COLLISION CHECK IS ON THE `classes` SPINE, NOT THE NODE ENTRY ──
    # A node reaching a parametric aspect refuses when its content is read. Its `bindings` stay
    # readable, so a map does not make a bindings read walk the closure.
    test-a-bindings-read-forces-no-closure = {
      expr =
        realizes
          (projectWith {
            a = [
              "web"
              "p"
            ];
          } { deliveryClasses.a.T = "T1"; }).nodes.a.bindings.node;
      expected = true;
    };
    # CONTROL in the same run: the same node's `classes` DOES refuse, so the clean read above is
    # not a node with nothing to refuse.
    test-control-the-classes-read-refuses = {
      expr =
        realizes
          (projectWith {
            a = [
              "web"
              "p"
            ];
          } { deliveryClasses.a.T = "T1"; }).nodes.a.classes;
      expected = false;
    };
  };
}
