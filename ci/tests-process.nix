# THE PER-PROCESS RUNNER (den-hoag-ien5k). Evaluates each cell in `tests-process-cells.nix` in its OWN
# evaluator process and asserts on the exit status, the printed value, the spy's trace count and the
# evaluator's thunk count — gen-aspects' `ci/tests-process.nix` is the pattern. A count is evidence
# only for the evaluator that computed it, so as `apps.<system>.tests-process` it calls the
# `nix-instantiate` on PATH, and gen-harness's `ci --tests-process` runs it in every column of
# `evaluators.yml`. Locally:
#   nix develop ./ci --command ci --tests-process
#
# gen-merge and gen-schema are read off gen-aspects' own `inputs`, gen-types, gen-memo and gen-scope
# off gen-merge's, and gen-graph off gen-schema's: the edges `flake.lock` already records, so the
# plane adds no pin.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      apps.tests-process.program = pkgs.writeShellScriptBin "tests-process" (
        ''
          set -e
          # The tools the body calls, declared rather than ambient — and never an evaluator.
          export PATH=${
            pkgs.lib.makeBinPath [
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gnused
            ]
          }:$PATH
          export cells=${./tests-process-cells.nix} libSrc=${../lib} fixtureSrc=${./one-host-fixture.nix}
          export genPreludeSrc=${inputs.gen-prelude} genAlgebraSrc=${inputs.gen-algebra}
          export genScopeSrc=${inputs.gen-scope} genAspectsSrc=${inputs.gen-aspects}
          export genIdentitySrc=${inputs.gen-aspects.inputs.gen-identity}
          export genAspectsAlgebraSrc=${inputs.gen-aspects.inputs.gen-algebra}
          export genMergeSrc=${inputs.gen-aspects.inputs.gen-merge} genSchemaSrc=${inputs.gen-aspects.inputs.gen-schema}
          export genTypesSrc=${inputs.gen-aspects.inputs.gen-merge.inputs.gen-types}
          export genMemoSrc=${inputs.gen-aspects.inputs.gen-merge.inputs.gen-memo}
          export genGraphSrc=${inputs.gen-aspects.inputs.gen-schema.inputs.gen-graph}
          # A fresh working directory per run (gen-harness `process-plane.nix`).
          TMPDIR=$(mktemp -d) out=$(mktemp)
          export TMPDIR out
          trap 'rm -rf "$TMPDIR" "$out"' EXIT
          cd "$TMPDIR"
          # The evaluator the cells run under, from this process and the binary they call.
          echo "evaluator: $(nix-instantiate --version | sed -n 1p)"
        ''
        + ''
          export NIX_STATE_DIR=$TMPDIR/nix-state NIX_LOG_DIR=$TMPDIR/nix-log
          ran=0
          # The spy's trace label, generated fresh per run and never written down, so no text a cell
          # or a document carries can be mistaken for a firing.
          label="spy-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
          die() {
            echo "tests-process: FAILED at cell $1: $2" >&2
            exit 1
          }
          # at <arm> <n> <expected value>: runs one cell in its own process with the evaluator's
          # statistics on, and leaves `thunks` and `resolves` set. Statistics that were not written
          # die as COULD NOT MEASURE, never read as a count.
          at() {
            rm -f "$TMPDIR/stats"
            rc=0
            val=$(NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$TMPDIR/stats" \
              nix-instantiate --eval --strict --readonly-mode \
              --argstr arm "$1" \
              --argstr libSrc "$libSrc" \
              --argstr fixtureSrc "$fixtureSrc" \
              --argstr genPreludeSrc "$genPreludeSrc" \
              --argstr genIdentitySrc "$genIdentitySrc" \
              --argstr genGraphSrc "$genGraphSrc" \
              --argstr genAlgebraSrc "$genAlgebraSrc" \
              --argstr genScopeSrc "$genScopeSrc" \
              --argstr genTypesSrc "$genTypesSrc" \
              --argstr genMemoSrc "$genMemoSrc" \
              --argstr genMergeSrc "$genMergeSrc" \
              --argstr genSchemaSrc "$genSchemaSrc" \
              --argstr genAspectsSrc "$genAspectsSrc" \
              --argstr genAspectsAlgebraSrc "$genAspectsAlgebraSrc" \
              --argstr label "$label" \
              --argstr n "$2" \
              "$cells" 2> "$TMPDIR/err") || rc=$?
            ran=$((ran + 1))
            [ "$rc" -eq 0 ] || die "$1" "n=$2: expected exit 0, got $rc: $(grep error "$TMPDIR/err" | head -2)"
            [ "$val" = "$3" ] || die "$1" "n=$2: expected $3, got '$val'"
            [ -s "$TMPDIR/stats" ] || die "$1" "n=$2: could not measure, no statistics written"
            thunks=$(sed -n 's/.*"nrThunks": *\([0-9][0-9]*\).*/\1/p' "$TMPDIR/stats")
            [ -n "$thunks" ] || die "$1" "n=$2: could not measure, no nrThunks in the statistics"
            resolves=$(grep -c "trace: $label\$" "$TMPDIR/err" || true)
          }

          # den-hoag-ien5k G1a: one host's artifact resolves the same number of times at every fleet
          # size. Forcing every node's order reads 2 per node.
          at one 1 '[ "a" ]'; t1=$thunks r1=$resolves
          at one 4 '[ "a" ]'; r4=$resolves
          at one 16 '[ "a" ]'; t16=$thunks r16=$resolves
          echo "one-host-resolves: $r1 / $r4 / $r16 at n = 1 / 4 / 16"
          [ "$r1" -gt 0 ] || die one-host-resolves "could not measure: the spy never fired at n = 1"
          [ "$r4" = "$r1" ] && [ "$r16" = "$r1" ] \
            || die one-host-resolves "resolve calls grow with the fleet: $r1 / $r4 / $r16 at n = 1 / 4 / 16"

          # G1b: one host's read costs the membership floor plus at most 20 thunks per host, the
          # figure measured on all three evaluators after the shared facts (the unshared reach read
          # 1,200 per host, the first shared cut 60).
          at members 1 1; m1=$thunks
          at members 16 16; m16=$thunks
          s=$(((t16 - t1) - (m16 - m1)))
          echo "one-host-slope: $s thunks above the membership floor over 15 hosts ($t1 / $t16 read, $m1 / $m16 floor)"
          [ "$s" -gt 0 ] || die one-host-slope "could not measure: no cost above the floor ($t1 / $t16, $m1 / $m16)"
          [ "$s" -le $((15 * 20)) ] \
            || die one-host-slope "one host's read costs more than 20 thunks per host above the floor: $s over 15 hosts"

          # G1c: the three-member arm, a static reach that is a union: the resolve count flat, and at
          # most 43 thunks per host above its floor (measured on all three evaluators).
          at one3 1 '[ "a" "b" "c" ]'; u1=$thunks q1=$resolves
          at one3 4 '[ "a" "b" "c" ]'; q4=$resolves
          at one3 16 '[ "a" "b" "c" ]'; u16=$thunks q16=$resolves
          echo "three-member-resolves: $q1 / $q4 / $q16 at n = 1 / 4 / 16"
          [ "$q1" -gt 0 ] || die three-member-resolves "could not measure: the spy never fired at n = 1"
          [ "$q4" = "$q1" ] && [ "$q16" = "$q1" ] \
            || die three-member-resolves "resolve calls grow with the fleet: $q1 / $q4 / $q16 at n = 1 / 4 / 16"
          at members3 1 1; k1=$thunks
          at members3 16 16; k16=$thunks
          s3=$(((u16 - u1) - (k16 - k1)))
          echo "three-member-slope: $s3 thunks above the membership floor over 15 hosts"
          [ "$s3" -gt 0 ] || die three-member-slope "could not measure: no cost above the floor ($u1 / $u16, $k1 / $k16)"
          [ "$s3" -le $((15 * 43)) ] \
            || die three-member-slope "one host's read costs more than 43 thunks per host above the floor: $s3 over 15 hosts"

          # 0/0 is a false pass: the runner must have executed every evaluation above.
          [ "$ran" = "10" ] || die runner "expected 10 evaluations, ran $ran"
          echo "tests-process: 4 cells, every exit read unpiped, every count read" > $out
        ''
        + ''
          cat "$out"
        ''
      );
    };
}
