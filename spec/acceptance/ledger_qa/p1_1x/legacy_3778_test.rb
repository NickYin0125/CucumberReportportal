# frozen_string_literal: true

require "minitest/autorun"
require_relative "legacy_3778"

class Legacy3778ContentTest < Minitest::Test
  def row
    { "index" => 3, "message" => "back\\slash", "frames" => ["exact/path.rb:42:in 'run'"],
      "raw_error" => "back\\slash\nexact/path.rb:42:in 'run'",
      "raw_sha256" => Digest::SHA256.hexdigest("back\\slash\nexact/path.rb:42:in 'run'") }
  end
  def card
    fence = 96.chr * 3
    "## \u2717 RuntimeError: back\\\\slash\n\n#{fence}text\nexact/path.rb:42:in 'run'\n#{fence}"
  end
  def test_exact_raw_content_passes_without_changing_a_path
    assert P1Legacy3778.content_check(row, { "message" => card })[:raw_failure_equal]
  end
  def test_a_single_frame_byte_fails
    result = P1Legacy3778.content_check(row, { "message" => card.sub("path.rb:42", "path.rb:43") })
    refute result[:raw_failure_equal]
    refute result[:frames_equal]
  end
  def test_multiline_message_is_not_mistaken_for_a_frame
    input = row.merge("message" => "first\nsecond", "raw_error" => "first\nsecond\nexact/path.rb:42:in 'run'")
    fence = 96.chr * 3
    text = "## \u2717 RuntimeError: first\n\n#{fence}text\nsecond\n#{fence}\n\n" + card.split("\n\n", 2).last
    assert P1Legacy3778.content_check(input, { "message" => text })[:raw_failure_equal]
  end
  def test_omission_or_incomplete_fence_is_not_a_pass
    refute P1Legacy3778.content_check(row, { "message" => "[REDACTED]" })[:raw_failure_equal]
    assert_raises(RuntimeError) { P1Legacy3778.text_fences((96.chr * 3) + "text\nlost") }
  end
end
