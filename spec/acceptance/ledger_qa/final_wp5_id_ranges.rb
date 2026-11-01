# frozen_string_literal: true

module LedgerQAIdRanges
  def self.encode(ids)
    raise "IDs must be unique nonnegative integers" unless ids.all? { |id| id.is_a?(Integer) && id >= 0 } && ids.uniq.length == ids.length
    return "N/A" if ids.empty?
    runs = []
    ids.sort.each do |id|
      if runs.last && id == runs.last.last + 1
        runs.last[1] = id
      else
        runs << [id, id]
      end
    end
    runs.map { |first, last| first == last ? first.to_s : "#{first}-#{last}" }.join(", ")
  end

  def self.decode(text)
    return [] if text == "N/A"
    ids = text.split(", ").flat_map do |piece|
      match = /\A(\d+)(?:-(\d+))?\z/.match(piece)
      raise "Invalid ID range" unless match
      first = Integer(match[1], 10)
      last = match[2] ? Integer(match[2], 10) : first
      raise "Reversed ID range" if last < first
      (first..last).to_a
    end
    raise "Overlapping ID ranges" unless ids.uniq.length == ids.length
    ids
  end

  def self.checked(ids)
    text = encode(ids)
    raise "ID membership changed" unless decode(text) == ids.sort
    text
  end
end

if $PROGRAM_NAME == __FILE__
  require "json"
  cases = { [] => "N/A", [7] => "7", [9, 1, 2, 4, 7, 8] => "1-2, 4, 7-9",
    [10, 12] => "10, 12", [100, 101, 102, 104, 105, 108] => "100-102, 104-105, 108" }
  cases.each do |ids, expected|
    raise "Wrong encoded membership" unless LedgerQAIdRanges.checked(ids) == expected
  end
  ["9-7", "1-3, 3", "1..3"].each do |invalid|
    rejected = false
    begin
      LedgerQAIdRanges.decode(invalid)
    rescue RuntimeError
      rejected = true
    end
    raise "Accepted invalid range" unless rejected
  end
  begin
    LedgerQAIdRanges.encode([1, 1])
    raise "Duplicate input accepted"
  rescue RuntimeError => error
    raise unless error.message == "IDs must be unique nonnegative integers"
  end
  puts JSON.generate(status: "PASS", assertions: 14, coverage: "Empty, singleton, contiguous runs, gaps, unsorted IDs, reversed/overlapping/invalid ranges, duplicate rejection; each render also verifies exact round-trip membership")
end
