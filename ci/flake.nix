{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";

    # nixpkgs is the CI runner's dependency (nix-unit harness, treefmt) and supplies the `lib` the
    # test modules use. It enters ONLY in ci/, never as a `lib/` dep: the library (../lib) is
    # nixpkgs-lib-free, which ci/tests/purity.nix enforces.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    # THE SUBSTRATE. The library takes it injected, so the library itself declares no dependency on
    # it — but the ACCEPTANCE RUN must supply one, and gen-aspects is it. gen-merge and gen-schema
    # are reached THROUGH that pin rather than declared beside it: the fixtures build a real aspect
    # schema and flatten its resolved tree, and two gen-merge instances would make a fixture a
    # question about which copy answered.
    gen-aspects.url = "github:sini/gen-aspects";

    # The other injected half: the record algebra whose ordered layered fold this surface's
    # contribution order is expressed over. Declared beside gen-aspects rather than reached through
    # it — nothing here compares a value that crosses between the two, so a single instance of each
    # is all the acceptance run owes.
    gen-algebra.url = "github:sini/gen-algebra";

    # The resolution calculus `project`'s query runs in, injected like the other three. Cells
    # doctor its `resolve` (`genDeliveryWith`) to show the query is read, and read as a set.
    gen-scope.url = "github:sini/gen-scope";
  };

  outputs =
    inputs@{
      gen-harness,
      gen-aspects,
      gen-algebra,
      gen-scope,
      nixpkgs,
      ...
    }:
    let
      aspects = gen-aspects.lib;
      algebra = gen-algebra.lib;
      # The third injected value, reached THROUGH the gen-aspects pin for the same reason gen-merge
      # and gen-schema are: one gen-prelude instance, so a door-check cell never asks which copy
      # answered.
      prelude = gen-aspects.inputs.gen-prelude.lib;
      genMerge = gen-aspects.inputs.gen-merge.lib;
      genSchema = gen-aspects.inputs.gen-schema.lib;

      scope = gen-scope.lib;
      genDeliveryWith =
        scope:
        import ../lib {
          inherit
            algebra
            aspects
            prelude
            scope
            ;
        };
      genDelivery = genDeliveryWith scope;

      # The fixture builder: a real aspect schema, resolved through gen-merge's byte-mode
      # `evalModuleTree`, exactly as a consumer's own composition would reach this surface. It
      # returns BOTH halves the surface needs — the resolved `values` and the `cnf` the schema was
      # built from — because a fixture that returned only the values would leave the declaration
      # unreachable, which is the very defect this library exists to fix.
      mkFixture =
        {
          cnf,
          modules,
        }:
        let
          schema = aspects.mkAspectSchema cnf;
          hostKinds = genSchema.evalSchema {
            modules = [
              {
                config.schema.host = {
                  options.addr = genMerge.mkOption { type = genMerge.types.str; };
                  options.aspects = genMerge.mkOption {
                    type = genMerge.types.listOf genMerge.types.str;
                    default = [ ];
                  };
                };
              }
            ];
          };
          hostSchema = {
            options.hosts = genSchema.mkInstanceRegistry hostKinds.host { };
          };
          evaluated = genMerge.evalModuleTree {
            modules = [
              { options.aspects = schema.mkAspectOption { }; }
              hostSchema
            ]
            ++ modules;
          };
        in
        {
          inherit cnf;
          values = evaluated.config;
        };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-delivery";
      testModules = ./tests;
      specialArgs = {
        inherit
          genDelivery
          genDeliveryWith
          scope
          mkFixture
          aspects
          algebra
          genMerge
          genSchema
          nixpkgs
          ;
        # gen-aspects' own term formers, minted by its own gen-identity, for a guard body that reads
        # the context (a term crosses into gen-aspects' guard, so it is built by that pin's algebra).
        term =
          (gen-aspects.inputs.gen-algebra.lib.term gen-aspects.inputs.gen-identity.lib.hashIdentity).term;
      };
      # Cells whose subject is an error MESSAGE cannot live under `testModules`: the batch asserter
      # behind `checks.default` quantifies over `flake.tests` and forces every `expr`
      # unconditionally, so a cell with no `expected` and a throwing `expr` CRASHES that gate
      # instead of failing it. They get their own output, read by
      # `nix-unit --flake ./ci#testsError`, and being outside ./tests is what keeps that split
      # structural rather than conventional.
      extraModules = [
        ./tests-error.nix
      ];
    };
}
