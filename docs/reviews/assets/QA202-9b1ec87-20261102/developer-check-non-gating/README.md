# Non-gating developer timing check (NOT a G11 result)

Host Ruby 3.4.2 on macOS, no container, no quiet window, host 1-min loadavg ~27 on 8 CPUs.
`bundle exec` from the SDK worktree also loaded that worktree's `version.rb` before the arm's `lib`; the evidence-redactor files were asserted to come from each arm.
Uses `Ledger202Benchmark.measure` with the gate stubbed, plain mode only, frozen 21-case corpus, 1050 samples per boundary per run, two rounds.
Raw samples (ms) are in the JSON files. Indicative only; must not be cited as PASS.

| arm | source | full p95 r1 / r2 (ms) | renderer p95 r1 / r2 (ms) |
| --- | --- | --- | --- |
| base | 3f20313c staged snapshot | 5.110 / 5.017 | 0.805 / 0.786 |
| 50b | 50b6d4d1 staged snapshot | 3.028 / 2.936 | 0.711 / 0.741 |
| 9b1 | 9b1ec873 git archive | 3.366 / 2.977 | 0.837 / 0.727 |
