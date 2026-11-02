# Offline only: validates existing evidence and builds review indexes.
require 'json'
require 'digest'
require 'open3'
require 'time'

ROOT = File.realpath(__dir__)
CAPTURES = File.join(ROOT, 'captures.json')
RECORDS = File.join(ROOT, 'record-ids.json')
base_captures = JSON.parse(File.read(CAPTURES))
post_path = File.join(ROOT, 'post-recovery-captures.json')
post_captures = File.exist?(post_path) ? JSON.parse(File.read(post_path)) : []
captures = base_captures + post_captures
records = JSON.parse(File.read(RECORDS))
input_hashes = [CAPTURES, RECORDS].to_h { |p| [File.basename(p), Digest::SHA256.file(p).hexdigest] }
errors = []
previous_manifest_path = File.join(ROOT, 'evidence-manifest.json')
if File.exist?(previous_manifest_path)
  previous_manifest = JSON.parse(File.read(previous_manifest_path))
  previous_manifest.fetch('screenshots', []).each do |entry|
    next unless entry['sha256']
    current_hash = Digest::SHA256.file(File.join(ROOT, entry.fetch('file'))).hexdigest
    errors << "Previously indexed screenshot changed: #{entry['id']}" unless current_hash == entry['sha256']
  end
  previous_manifest.fetch('immutable_input_sha256', {}).each do |name, hash|
    errors << "Original input changed: #{name}" unless Digest::SHA256.file(File.join(ROOT, name)).hexdigest == hash
  end
end
supplements = {}
def add_records(target, numbers, items, logs)
  numbers.each { |n| target[format('VR20202-E%03d', n)] = { 'items' => items, 'logs' => logs } }
end
add_records(supplements, [7, 8, 9], [31758], [21176, 21177, 21178])
add_records(supplements, [10, 11], [31779], [21211])
add_records(supplements, [12, 13], [31845], [21300, 21301, 21302, 21303])
add_records(supplements, [14, 15], [31845], [21302, 21303])
add_records(supplements, [18, 19], [31595], [20966, 20967, 20968])
add_records(supplements, [20, 21], [31695], [21110, 21111])
add_records(supplements, [22], [31626], [21012])
add_records(supplements, [23, 24], [31629, 31632], [21016, 21023, 21024])
add_records(supplements, [36, 37], [31881, 31883], [21339, 21340, 21341, 21342, 21343, 21345, 21346])
add_records(supplements, [39, 40], [31860, 31861], [21321, 21322])
add_records(supplements, [45, 46], [31731], [21147, 21148, 21149, 21150, 21151])
add_records(supplements, [47, 48], [31587], [20957, 20958, 20959, 20960, 20961])
add_records(supplements, [57], [31850], [21310, 21311, 21312, 21313])

qualifications = {
  1 => 'Only the top six final launch rows are comparable; preliminary row at bottom excluded.',
  2 => 'API tester row is partly below the fold; E001 supplies its complete launch row.',
  9 => 'Scrolled transport-detail view; HTTP heading is above viewport. Pair with E007/E008.',
  25 => 'Improved failure caption does not resolve V08 at the original successful-image targets.',
  26 => 'Improved failure caption does not resolve V08 at the original successful-image targets.',
  29 => 'Supporting filter/count evidence only: After row below viewport. E044 is direct R02 proof.',
  41 => 'Failure-caption improvement, not a fix for the original generic successful-image captions.',
  47 => 'New API tester is rich; old tester was plain. Not a controlled mode-only comparison.',
  48 => 'New API tester is rich; old tester was plain. Not a controlled mode-only comparison.',
  57 => 'Multiline All Logs comparison, not a whitespace-only/boundary-whitespace test or Stack Trace.'
}
tree_ids = [1, 2, 3, 4, 5, 6, 17, 50, 55, 56]
stack_ids = [14, 15, 16, 20, 21, 39, 40, 54]
viewer_ids = [27, 28, 34, 35, 38]
inventory = captures.map do |original|
  entry = Marshal.load(Marshal.dump(original))
  number = entry.fetch('id').split('E').last.to_i
  path = File.expand_path(entry.fetch('file'), ROOT)
  raise 'Evidence path outside owned directory' unless path.start_with?(ROOT + '/')
  bytes = File.binread(path)
  output, diagnostic, status = Open3.capture3('/usr/bin/sips', '-g', 'pixelWidth', '-g', 'pixelHeight', path)
  dimensions = [output[/pixelWidth:\s+(\d+)/, 1].to_i, output[/pixelHeight:\s+(\d+)/, 1].to_i]
  expected = entry.fetch('viewport').values_at('width', 'height')
  valid_jpeg = bytes.start_with?("\xFF\xD8".b) && bytes.end_with?("\xFF\xD9".b)
  errors << "#{entry['id']}: invalid JPEG boundaries" unless valid_jpeg
  errors << "#{entry['id']}: unreadable image metadata" unless status.success?
  errors << "#{entry['id']}: dimension mismatch #{dimensions.inspect}" unless dimensions == expected
  errors << "#{entry['id']}: unexpected viewport" unless [1100, 1440].include?(dimensions[0]) && dimensions[1] == 1000 && entry['viewport']['device_pixel_ratio'] == 1
  entry['bytes'] = bytes.bytesize
  entry['sha256'] = Digest::SHA256.hexdigest(bytes)
  entry['verified_dimensions'] = { 'width' => dimensions[0], 'height' => dimensions[1] }
  entry['jpeg_boundaries_valid'] = valid_jpeg
  entry['capture_method'] = 'CUA tab.screenshot; original unmodified JPEG viewport capture'
  entry['browser'] = { 'name' => 'Edge', 'tab_id' => '148298242', 'ownership' => 'independently created review tab' }
  entry['view'] ||= if tree_ids.include?(number)
                      'Launch list or item tree'
                    elsif stack_ids.include?(number)
                      'Stack Trace'
                    elsif viewer_ids.include?(number)
                      'Opened attachment'
                    else
                      'All Logs'
                    end
  entry['filter'] ||= if [29, 44].include?(number)
                        'Hide All Passed Logs on'
                      elsif tree_ids.include?(number)
                        'Log filter not applicable'
                      else
                        'Hide All Passed Logs off; see visible screenshot for other controls'
                      end
  entry['qualification'] = qualifications[number] if qualifications.key?(number)
  extra = supplements.fetch(entry['id'], { 'items' => [], 'logs' => [] })
  entry['corroborated_items'] = ([entry['item']] + Array(entry['items']) + extra['items']).compact.uniq
  entry['corroborated_logs'] = (Array(entry['logs']) + extra['logs']).uniq
  launch = entry['launch']&.to_s
  if launch && records.key?(launch)
    index = records[launch].to_h { |i| [i.fetch('id'), i] }
    log_index = records[launch].flat_map { |i| i['logs'] }.to_h { |g| [g.fetch('id'), g] }
    ([entry['scenario'], entry['feature']] + entry['corroborated_items']).compact.each do |id|
      errors << "#{entry['id']}: item #{id} absent from saved launch #{launch}" unless index.key?(id)
    end
    entry['corroborated_logs'].each do |id|
      log = log_index[id]
      errors << "#{entry['id']}: log #{id} absent from saved launch #{launch}" unless log
      if log && !entry['corroborated_items'].include?(log['itemId'])
        errors << "#{entry['id']}: log #{id} not owned by cited item"
      end
    end
    entry['record_id_provenance'] = 'Own pre-outage item-scoped GET inventory, matched to rendered scenario/context; not all cited rows necessarily fit this viewport'
  else
    entry['record_id_provenance'] = 'Own prior visual-review.md plus independently revisited rendered UI; launch/item surface may have no logs'
  end
  entry
end

expected_ids = (1..57).map { |n| format('VR20202-E%03d', n) }
expected_ids += (59..(58 + post_captures.size)).map { |n| format('VR20202-E%03d', n) } unless post_captures.empty?
errors << 'Unexpected capture ID sequence' unless inventory.map { |e| e['id'] } == expected_ids
expected_files = inventory.map { |e| File.join(ROOT, e['file']) }.sort
actual_files = Dir[File.join(ROOT, 'screenshots', '*')].select { |p| File.file?(p) }.sort
errors << 'Unindexed or missing screenshot files' unless expected_files == actual_files
records.each do |launch, items|
  items.each do |item|
    item['logs'].each do |log|
      errors << "Launch #{launch}: log #{log['id']} has wrong item owner" unless log['itemId'] == item['id']
    end
  end
end
input_hashes.each do |name, hash|
  errors << "Input changed during validation: #{name}" unless Digest::SHA256.file(File.join(ROOT, name)).hexdigest == hash
end
raise errors.join("\n") unless errors.empty?

launches = [
  [3849, 3837, 'api_example', 'plain', 14, 2], [3850, 3838, 'ui_example', 'plain', 8, 2],
  [3851, 3839, 'api_example', 'rich', 14, 2], [3852, 3840, 'ui_example', 'rich', 8, 2],
  [3847, 3842, 'api_tester', 'rich', 1, 1], [3848, 3841, 'ui_tester', 'rich', 1, 1]
].map do |id, old, suite, mode, passed, failed|
  { 'launch_id' => id, 'baseline_launch_id' => old, 'suite' => suite, 'presentation' => mode,
    'passed' => passed, 'failed' => failed, 'baseline_presentation' => (suite.end_with?('tester') ? 'plain' : mode) }
end
manifest = {
  'review' => 'SDK 2.0.2 independent visual review', 'status' => 'offline_report_complete_live_followup_held',
  'finalized_at' => Time.now.utc.iso8601, 'endpoint' => 'http://rp-2607.localhost:18080', 'project' => 'superadmin_personal',
  'rp_ui_build_observed' => '5.15.6', 'reviewed_launch_head_supplied' => '9bf3356cff350d8e2ba11bad1c33aa89881ac456',
  'latest_source_head_supplied' => 'd1725d3ab9e796c008fe9e80a11ea0ce29bde762',
  'identity_provenance' => 'User/Master handoff only. Runtime/examples/Gemfile/gemspec equivalence and CI/integration-only followup not independently verified. No final-head rerun.',
  'runtime_supplied' => { 'gem' => '2.0.2 normal installation', 'ruby' => '3.4.2', 'cucumber' => '12.0.1', 'cucumber_core' => '20.1.0', 'playwright' => '1.62.0' },
  'new_launches' => launches, 'excluded_preliminary_launches' => [3843, 3844, 3845, 3846],
  'capture_window_utc' => [base_captures.first['captured_at'], base_captures.last['captured_at']],
  'surface_scores' => [
    ['S01', 3, 3, [1, 2, 3, 4]], ['S02', 4, 4, [5, 6, 17, 50, 55, 56]],
    ['S03', 3, 4, [10, 11, 22, 23, 25, 31, 42, 44]], ['S04', 2, 4, [12, 13, 14, 15, 16, 20, 21, 23, 24, 39, 40, 54]],
    ['S05', 3, 4, [7, 8, 9, 18, 19, 51]], ['S06', 4, 4, [12, 13, 36, 37, 45, 46, 47, 48, 57]],
    ['S07', 3, 3, [25, 26, 32, 33, 36, 37, 41, 42, 43, 53]], ['S08', 4, 4, [27, 28, 34, 35, 38]],
    ['S09', 2, 4, [7, 9, 14, 15, 18, 20, 21, 36, 37, 39, 40, 45, 46]]
  ].map { |id, old, score, refs| { 'id' => id, 'old' => old, 'new' => score, 'evidence_ids' => refs.map { |n| format('VR20202-E%03d', n) } } },
  'original_issue_verdicts' => { 'V01' => 'fixed', 'V02' => 'fixed', 'V03' => 'fixed', 'V04' => 'fixed', 'V05' => 'fixed', 'V06' => 'fixed', 'V07' => 'partial', 'V08' => 'not_fixed', 'V09' => 'fixed', 'V10' => 'partial' },
  'owner_r02_status' => 'not_fixed; independently reproduced before outage; After ownership and PASSED hook retained',
  'new_issues' => [{ 'id' => 'N01', 'severity' => 'S3', 'title' => 'Verbose consolidated failure caption hides provenance and file metadata behind preview', 'launch' => 3852, 'item' => 31861, 'log' => 21322, 'evidence_ids' => ['VR20202-E041', 'VR20202-E042', 'VR20202-E043'] }],
  'screenshots' => inventory,
  'excluded_captures' => [{ 'attempted_id' => 'VR20202-E058', 'status' => 'not_saved_not_evidence', 'reason' => 'ENOSPC on both save attempts; no E058 file exists', 'intended_view' => '3851 contract expanded exception/full trace' }],
  'api_corroboration' => records.map { |id, items| { 'launch' => id.to_i, 'items' => items.size, 'item_scoped_logs' => items.sum { |i| i['logs'].size } } },
  'api_scope' => 'Own pre-outage read-only item/log inventory. No launch-scoped zero-log inference. No new API calls during offline completion.',
  'immutable_input_sha256' => input_hashes,
  'pending' => [
    'Any browser/API activity awaits explicit Master health clearance; outage not used for a product verdict.',
    'No d1725d3 rerun or source-equivalence verification.',
    'Expanded full-trace evidence save failed; no complete-frame-retention certification.',
    'No sampled FATAL, repeated-value headers, or independently captured whitespace-only/boundary-whitespace assertion proof.',
    'Plain expanded HTTP, expected-400 HTTP card, new tester before-refresh opened image, and native HTML report not fully captured.',
    'Viewport override restoration was not confirmed before urgent stop; do not access browser merely to reset while hold is active.'
  ]
}
unless post_captures.empty?
  reset = JSON.parse(File.read(File.join(ROOT, 'viewport-reset.json')))
  manifest['status'] = 'priority_post_recovery_visual_followup_complete'
  manifest['pre_recovery_pending'] = manifest['pending']
  manifest['pending'] = [
    'Whitespace-only/boundary-whitespace assertions, repeated-value headers, and FATAL remain unavailable-sample coverage boundaries; no new fixtures generated.',
    'Native HTML UI remains out of scope by user instruction; intentional RP-only failure PNG tradeoff unchanged.',
    'No final-head rerun, performance-fix verification, source-equivalence verification, or byte-identity certification. Existing launches only.'
  ]
  manifest['post_recovery'] = {
    'capture_window_utc' => [post_captures.first['captured_at'], post_captures.last['captured_at']],
    'capture_count' => post_captures.size,
    'existing_launches_visited' => [3848, 3849, 3851],
    'new_launches_generated' => 0,
    'new_direct_api_calls' => 0,
    'source_update_supplied' => '090b633: user states only example README and documentation spec changes after d1725d3; not independently verified.',
    'performance_boundary' => 'Owner-authorized performance work is separate. These old launches do not establish output equivalence for any optimization.',
    'closed_visual_gaps' => ['Expanded full-trace accessibility and saved top/end evidence', 'Expanded plain HTTP 201 and expected-400 details', 'Before-refresh and After-owned failure PNG pair'],
    'full_trace_scope' => 'L3851 I31845 G21303: UI label reports 88 frames; rendered pre block has 88 newline-delimited lines, focused block 7. E059/E060/E073 show top/end. Not equality to original exception bytes.',
    'qualified_capture' => 'E061 fullPage request returned only app viewport due internal scrolling; not used as full-trace proof.',
    'viewport_reset' => reset,
    'original_verdicts_and_warnings_changed' => false
  }
  manifest['api_scope'] += ' Post-recovery IDs reuse this saved inventory; no direct API calls were needed.'
  manifest['surface_scores'].each do |score|
    additions = case score['id']
                when 'S04' then [59, 60, 73]
                when 'S05' then [62, 63, 64, 65, 66, 72]
                when 'S07' then [67]
                when 'S08' then [68, 69, 70, 71]
                when 'S09' then [64, 72]
                else []
                end
    score['post_recovery_evidence_ids'] = additions.map { |n| format('VR20202-E%03d', n) } unless additions.empty?
  end
end
validation = {
  'validated_at' => Time.now.utc.iso8601, 'validation_process_offline_only' => true, 'result' => 'pass', 'errors' => errors,
  'capture_count' => inventory.size, 'total_screenshot_bytes' => inventory.sum { |e| e['bytes'] },
  'original_capture_count' => base_captures.size, 'post_recovery_capture_count' => post_captures.size,
  'checks' => ['Unique sequential saved evidence IDs with E058 intentionally absent', 'Previously indexed screenshots unchanged', 'No missing, empty, or unindexed screenshot files',
               'JPEG start/end markers and sips-readable dimensions', 'Actual dimensions match recorded 1100/1440 x 1000 DPR1 viewports',
               'SHA-256 and byte length for every screenshot', 'All cited new item/log IDs belong to saved launch/item records',
               'Original captures.json and record-ids.json unchanged'],
  'limitations' => ['Hashes are local integrity fingerprints, not build provenance or comparison to source PNG bytes.',
                    'Metadata validation is not an exhaustive image-decoder or visual-content test.',
                    'Old record IDs derive from the permitted baseline and rendered UI, not a new offline API query.']
}
File.write(File.join(ROOT, 'evidence-manifest.json'), JSON.pretty_generate(manifest) + "\n")
File.write(File.join(ROOT, 'validation.json'), JSON.pretty_generate(validation) + "\n")
lines = ["# SDK 2.0.2 Visual Evidence Index", "", "#{base_captures.size} original pre-outage CUA screenshots plus #{post_captures.size} post-recovery captures. Previously indexed screenshot bytes remain unchanged.",
         "", "`E###` in the report means `VR20202-E###`. Full hashes, capture times, URLs, related record IDs and qualifications are in [evidence-manifest.json](#{ROOT}/evidence-manifest.json).", "",
         "| Evidence | Actual Viewport | Launch / Related Item / Log IDs | Qualification |", "| --- | --- | --- | --- |"]
inventory.each do |e|
  title = File.basename(e['file']).sub(/\.jpg$/, '')
  ids = "L #{e['launch'] || Array(e['launches']).join('/')} / I #{e['corroborated_items'].join('/')} / G #{e['corroborated_logs'].join('/')}"
  lines << "| [#{e['id']}](#{ROOT}/#{e['file']}) - #{title} | #{e['viewport']['width']} x #{e['viewport']['height']}, DPR 1 | #{ids} | #{e['qualification'] || 'Saved rendered viewport; surrounding context may be outside the frame.'} |"
end
lines += ["", "E058 was not saved because the disk was full. It is excluded, not counted as evidence.",
          "E029 is supporting evidence only; E044 directly demonstrates After evidence disappearing under the passed-log filter."]
if post_captures.empty?
  lines << "No post-outage browser/API checks were made. All live followup remains held pending Master health clearance."
else
  lines += ["E061 is a preserved full-page attempt that captured only the app viewport; it is not full-trace proof.",
            "Priority post-recovery observations used only existing launches after explicit user clearance. No new direct API calls or generated launches. Viewport override reset.",
            "See [post-recovery-review.md](#{ROOT}/post-recovery-review.md) for the supplemental conclusions and remaining boundaries."]
end
File.write(File.join(ROOT, 'evidence-index.md'), lines.join("\n") + "\n")
puts JSON.generate(validation.slice('result', 'capture_count', 'total_screenshot_bytes', 'errors'))
