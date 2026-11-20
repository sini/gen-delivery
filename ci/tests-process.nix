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
          export forwardFixtureSrc=${./forward-fixture.nix} nixpkgsSrc=${inputs.nixpkgs}
          # A fresh working directory per run (gen-harness `process-plane.nix`).
          TMPDIR=$(mktemp -d) out=$(mktemp)
          export TMPDIR out
          trap 'rm -rf "$TMPDIR" "$out"' EXIT
          cd "$TMPDIR"
          # The evaluator the cells run under, from this process and the binary they call.
          echo "evaluator: $(nix-instantiate --version | sed -n 1p)"
          # A thunk count is defined only for a serial run, so every cell below (`at`, whose statistics are a
          # command prefix) is serial. The options are resolved once (gen-harness `lib.serialEval`).
          # shellcheck disable=SC1091
          source ${inputs.gen-harness.lib.serialEval { inherit pkgs; }}
          serialEvalOptions "$(command -v nix-instantiate)" || {
            echo "tests-process: CONTROL FAILED: the serial options of $(command -v nix-instantiate) could not be resolved" >&2
            exit 2
          }
          echo "tests-process: serial options: ''${SERIAL_EVAL[*]:-(none)}"
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
              nix-instantiate "''${SERIAL_EVAL[@]}" --eval --strict --readonly-mode \
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
              --argstr forwardFixtureSrc "$forwardFixtureSrc" \
              --argstr nixpkgsSrc "$nixpkgsSrc" \
              --argstr label "$label" \
              --argstr n "$2" \
              "$cells" 2> "$TMPDIR/err") || rc=$?
            ran=$((ran + 1))
            [ "$rc" -eq 0 ] || die "$1" "n=$2: expected exit 0, got $rc: $(grep error "$TMPDIR/err" | head -2)"
            [ "$val" = "$3" ] || die "$1" "n=$2: expected $3, got '$val'"
            [ -s "$TMPDIR/stats" ] || die "$1" "n=$2: could not measure, no statistics written"
            thunks=$(sed -n 's/.*"nrThunks": *\([0-9][0-9]*\).*/\1/p' "$TMPDIR/stats")
            [ -n "$thunks" ] || die "$1" "n=$2: could not measure, no nrThunks in the statistics"
            bytes=$(sed -n 's/.*"totalBytes": *\([0-9][0-9]*\).*/\1/p' "$TMPDIR/stats")
            [ -n "$bytes" ] || die "$1" "n=$2: could not measure, no gc.totalBytes in the statistics"
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

          # den-hoag-9z993 G1: the whole fleet's read costs at most 511 thunks per host above its floor on
          # every segment of four sizes, so the bound holds flat in n (measured on all three evaluators).
          # It pins `keyCategory cnf` bound once per `projectNodes`: re-entering gen-aspects' cnf door per
          # key per item read 759.
          ceil=511
          prev=
          for n in 2 4 8 16; do
            at every "$n" "$n"; e=$thunks
            at members "$n" "$n"; f=$thunks
            if [ -n "$prev" ]; then
              d=$(((e - pe) - (f - pf))) dn=$((n - prev))
              echo "fleet-per-host: $((d / dn)) thunks per host above the floor over n = $prev..$n ($pe / $e read, $pf / $f floor)"
              [ "$d" -gt 0 ] || die fleet-per-host "could not measure: no cost above the floor over n = $prev..$n"
              [ "$d" -le $((ceil * dn)) ] \
                || die fleet-per-host "the fleet's read costs more than $ceil thunks per host above the floor: $d over n = $prev..$n"
            fi
            prev=$n pe=$e pf=$f
          done

          # den-hoag-lrnaw, den-hoag-in23c: every route check runs once per route, in its bucket's memo,
          # so `forward` costs the same per route however wide the bucket. Checked per read it read
          # quadratic (16844 thunks per route over 16..64). Thunks are bounded per route by one flat
          # ceiling on both segments, 1..16 and 16..64 (the `fleet-per-host` form); bytes over 16..64 only
          # (Determinate allocates in blocks too coarse for 1..16), each bound measured on all three
          # evaluators. The k = 64 endpoint sits on a one-time step at k = 63 -> 64 (about +8700 thunks,
          # present before the memo too): it is part of 16..64's figure, not a slope to chase. Determinate's
          # byte bound leaves two 262144 B blocks over its figure, since its per-route bytes move by a
          # block between neighbouring k.
          at width 1 1; wt1=$thunks wb1=$bytes
          at width 16 16; wt16=$thunks wb16=$bytes
          at width 64 64; wt64=$thunks wb64=$bytes
          ta=$(((wt16 - wt1) / 15)) tb=$(((wt64 - wt16) / 48)) bb=$(((wb64 - wb16) / 48))
          echo "forward-width: $ta / $tb thunks per route over k = 1..16 / 16..64, $bb bytes over 16..64 ($wt1 / $wt16 / $wt64 thunks)"
          [ "$ta" -gt 0 ] && [ "$bb" -gt 0 ] || die forward-width "could not measure: no cost per route ($wt1 / $wt16 thunks, $wb16 / $wb64 bytes)"
          [ "$ta" -le 1400 ] && [ "$tb" -le 1400 ] \
            || die forward-width "a route costs more thunks as the bucket widens than bounded: $ta / $tb over k = 1..16 / 16..64"
          # Bytes per route differ by evaluator family as much as the defect does, so each has its own.
          case "$(nix-instantiate --version)" in
            *Lix*) bmax=109500 ;;
            *Determinate*) bmax=85000 ;;
            *) bmax=101000 ;;
          esac
          [ "$bb" -le "$bmax" ] \
            || die forward-width "a route costs more bytes as the bucket widens than bounded: $bb over k = 16..64, bound $bmax"

          # den-hoag-92bpu: a W1 hop carries its source's received set by reference, so a target's read costs
          # the same per hop however deep the relay (first slice section 2.10, "linear in relay depth").
          # Re-materialised per hop it read quadratic (1874 / 2793 thunks per hop over 16..32 / 32..64 on Nix).
          # Section 2.10 is amended for one class only: a W1 route whose placement reads `captured` (or a `ref`
          # that may resolve there) owes d(d+1)/2 (occurrence, hop) placement resolutions, each able to refuse
          # or regroup, so it is quadratic by the semantics (its module count only where the resolved values
          # differ). Merge points and closures where two routes select from one cell keep the claim: their
          # cost above linear is an owed defect, not a carve-out. This chain is outside that class.
          # Thunks are bounded per hop by one flat ceiling on both segments; bytes over 32..64, per evaluator
          # family, each bound measured on all three evaluators.
          at depth 1 1; dt1=$thunks
          at depth 16 16; dt16=$thunks
          at depth 32 32; dt32=$thunks db32=$bytes
          at depth 64 64; dt64=$thunks db64=$bytes
          da=$(((dt32 - dt16) / 16)) dc=$(((dt64 - dt32) / 32)) dbb=$(((db64 - db32) / 32))
          echo "forward-depth: $da / $dc thunks per hop over d = 16..32 / 32..64, $dbb bytes over 32..64 ($dt1 / $dt16 / $dt32 / $dt64 thunks)"
          [ "$da" -gt 0 ] && [ "$dbb" -gt 0 ] || die forward-depth "could not measure: no cost per hop ($dt16 / $dt32 thunks, $db32 / $db64 bytes)"
          [ "$da" -le 1300 ] && [ "$dc" -le 1300 ] \
            || die forward-depth "a hop costs more thunks as the relay deepens than bounded: $da / $dc over d = 16..32 / 32..64"
          case "$(nix-instantiate --version)" in
            *Lix*) dbmax=100000 ;;
            *Determinate*) dbmax=80000 ;;
            *) dbmax=95000 ;;
          esac
          [ "$dbb" -le "$dbmax" ] \
            || die forward-depth "a hop costs more bytes as the relay deepens than bounded: $dbb over d = 32..64, bound $dbmax"
          # Growth: bytes per hop at d = 512..1024 stay within 8% of 32..64, so a carriage that copies its
          # source's items into each cell (thunk-flat, bytes growing with the items carried) reds here
          # though it passes the bounds above: measured 1.152 / 1.152 on Nix / Lix against 1.005 / 1.005
          # for the reference carriage. Not read on Determinate: its block allocator moves this ratio more
          # than the defect does (1.114 reference, 1.097 copying).
          at depth 512 512; db512=$bytes
          at depth 1024 1024; db1024=$bytes
          dbg=$(((db1024 - db512) / 512))
          echo "forward-depth-growth: $dbg bytes per hop over d = 512..1024, $dbb over 32..64"
          [ "$dbg" -gt 0 ] || die forward-depth "could not measure: no bytes per hop over d = 512..1024 ($db512 / $db1024)"
          case "$(nix-instantiate --version)" in
            *Determinate*) ;;
            *)
              [ $((dbg * 100)) -le $((dbb * 108)) ] \
                || die forward-depth "a hop's bytes grow with the relay's depth: $dbg over d = 512..1024 against $dbb over 32..64, more than 8%"
              ;;
          esac

          # den-hoag-wk4in: a merge point carries its sources by reference too, so a target's read costs the same
          # per level however deep the merges (first slice section 2.10 keeps the claim for merge points). Two
          # classes, each re-materialising the received set per route per level before: twins (two routes
          # selecting one cell alike, the tree test read them as shared) read 2941 / 4127 thunks per level over
          # 16..32 / 32..64 on Nix, and a merge through distinct relay cells 12570 / 21426. Thunks are bounded
          # per level by one flat ceiling on both segments; bytes over 32..64, per evaluator family, each bound
          # measured on all three evaluators.
          at ladder 1 1; lt1=$thunks
          at ladder 16 16; lt16=$thunks
          at ladder 32 32; lt32=$thunks lb32=$bytes
          at ladder 64 64; lt64=$thunks lb64=$bytes
          la=$(((lt32 - lt16) / 16)) lc=$(((lt64 - lt32) / 32)) lbb=$(((lb64 - lb32) / 32))
          echo "forward-ladder: $la / $lc thunks per level over d = 16..32 / 32..64, $lbb bytes over 32..64 ($lt1 / $lt16 / $lt32 / $lt64 thunks)"
          [ "$la" -gt 0 ] && [ "$lbb" -gt 0 ] || die forward-ladder "could not measure: no cost per level ($lt16 / $lt32 thunks, $lb32 / $lb64 bytes)"
          [ "$la" -le 2000 ] && [ "$lc" -le 2000 ] \
            || die forward-ladder "a twin merge level costs more thunks as the ladder deepens than bounded: $la / $lc over d = 16..32 / 32..64"
          case "$(nix-instantiate --version)" in
            *Lix*) lbmax=140000 ;;
            *Determinate*) lbmax=130000 ;;
            *) lbmax=135000 ;;
          esac
          [ "$lbb" -le "$lbmax" ] \
            || die forward-ladder "a twin merge level costs more bytes as the ladder deepens than bounded: $lbb over d = 32..64, bound $lbmax"
          # Growth, as forward-depth's: bytes per level at d = 512..1024 within 15% of 32..64. A carriage that
          # copies the source's items into each twin (thunk-lighter than the reference) reads 1.270 / 1.266 on
          # Nix / Lix against 1.072 / 1.073. Not read on Determinate (its block allocator; 0.918 reference).
          at ladder 512 512; lb512=$bytes
          at ladder 1024 1024; lb1024=$bytes
          lbg=$(((lb1024 - lb512) / 512))
          echo "forward-ladder-growth: $lbg bytes per level over d = 512..1024, $lbb over 32..64"
          [ "$lbg" -gt 0 ] || die forward-ladder "could not measure: no bytes per level over d = 512..1024 ($lb512 / $lb1024)"
          case "$(nix-instantiate --version)" in
            *Determinate*) ;;
            *)
              [ $((lbg * 100)) -le $((lbb * 115)) ] \
                || die forward-ladder "a twin merge level's bytes grow with the ladder's depth: $lbg over d = 512..1024 against $lbb over 32..64, more than 15%"
              ;;
          esac
          at mergeDepth 1 1; mt1=$thunks
          at mergeDepth 16 16; mt16=$thunks
          at mergeDepth 32 32; mt32=$thunks mb32=$bytes
          at mergeDepth 64 64; mt64=$thunks mb64=$bytes
          ma=$(((mt32 - mt16) / 16)) mc=$(((mt64 - mt32) / 32)) mbb=$(((mb64 - mb32) / 32))
          echo "forward-merge-depth: $ma / $mc thunks per level over d = 16..32 / 32..64, $mbb bytes over 32..64 ($mt1 / $mt16 / $mt32 / $mt64 thunks)"
          [ "$ma" -gt 0 ] && [ "$mbb" -gt 0 ] || die forward-merge-depth "could not measure: no cost per level ($mt16 / $mt32 thunks, $mb32 / $mb64 bytes)"
          [ "$ma" -le 5000 ] && [ "$mc" -le 5000 ] \
            || die forward-merge-depth "a distinct-cell merge level costs more thunks as the merges deepen than bounded: $ma / $mc over d = 16..32 / 32..64"
          case "$(nix-instantiate --version)" in
            *Lix*) mbmax=350000 ;;
            *Determinate*) mbmax=260000 ;;
            *) mbmax=340000 ;;
          esac
          [ "$mbb" -le "$mbmax" ] \
            || die forward-merge-depth "a distinct-cell merge level costs more bytes as the merges deepen than bounded: $mbb over d = 32..64, bound $mbmax"

          # 0/0 is a false pass: the runner must have executed every evaluation above.
          [ "$ran" = "37" ] || die runner "expected 37 evaluations, ran $ran"
          echo "tests-process: 9 cells, every exit read unpiped, every count read" > $out
        ''
        + ''
          cat "$out"
        ''
      );
    };
}
