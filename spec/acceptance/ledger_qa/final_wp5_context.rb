# frozen_string_literal: true

module LedgerWP5Context
  DEFAULT_STAMP = "wp5-ci-final-20261101"
  HEADS = {
    "wp5-final-20261101" => { "2.0.1" => "06f498cf9fb05352a831fdafc9583b40dced9899", "1.3.2" => "1e136e89eb21276330e5fc9f1769fe9521a83cb9" },
    "wp5-final-rerun-20261101" => { "2.0.1" => "ff3268b945ab4fe4080be063567ea9b49c458def", "1.3.2" => "4ddb466f4f04ffe04f82042d9b1429faff74ffcc" },
    "wp5-ci-final-20261101" => { "2.0.1" => "3f20313c20b25071fbc49b31e1c6bc772bd599e4", "1.3.2" => "f41888a9fdd6896630765cbbf350353a7f803e59" }
  }.freeze

  def self.stamp
    ENV.fetch("QA_WP5_STAMP", DEFAULT_STAMP)
  end

  def self.heads
    HEADS.fetch(stamp.delete_suffix("-quiet"))
  end
end
