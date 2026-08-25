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
  };

  outputs =
    inputs@{
      gen-harness,
      gen-aspects,
      nixpkgs,
      ...
    }:
    let
      aspects = gen-aspects.lib;
      genMerge = gen-aspects.inputs.gen-merge.lib;
      genSchema = gen-aspects.inputs.gen-schema.lib;

      genDelivery = import ../lib { inherit aspects; };

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
          hostSchema =
            { config, ... }:
            {
              options.schema = genSchema.mkSchemaOption { };
              options.hosts = genSchema.mkInstanceRegistry config.schema.host { };
              config.schema.host = {
                options.addr = genMerge.mkOption { type = genMerge.types.str; };
                options.aspects = genMerge.mkOption {
                  type = genMerge.types.listOf genMerge.types.str;
                  default = [ ];
                };
              };
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
          mkFixture
          aspects
          genMerge
          genSchema
          nixpkgs
          ;
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
