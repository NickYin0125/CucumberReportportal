# Initial diagnostic run: mode-label defect

The original `performance/` run used the existing QA benchmark's constructor
call `Config.new("rp.presentation" => mode)`. `Config#initialize` only symbolizes
keys; it does not apply the dotted YAML option mapping. Thus the failure pipeline
always used `plain`, even for samples labelled `rich`.

These raw records are retained, but must not be cited as plain-versus-rich
performance certification. The old QA benchmark source was not modified.
The independent diagnostic harness now uses `Config.new(presentation: mode)`
and asserts both the resolved config mode and the renderer's received keyword.
All three runtime arms, both modes and both ordering rounds are rerun in
`performance-mode-verified/`. Source bytes, corpus, container and measurement
boundaries are unchanged. No SDK runtime change was required for this correction.
