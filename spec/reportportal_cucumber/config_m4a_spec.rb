# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Config do
  let(:m4a_defaults) do
    {
      queue_max_records: 1_000,
      queue_max_bytes: 16_777_216,
      batch_size_logs: 20,
      batch_max_bytes: 8_388_608,
      queue_overflow_policy: "reject_new",
      queue_admission_timeout_ms: 100
    }
  end

  it "provides the documented M4-A delivery defaults" do
    config = described_class.new

    m4a_defaults.each do |key, value|
      expect(config.public_send(key)).to eq(value)
    end
  end

  it "applies profile, environment, and explicit overrides in documented precedence order" do
    Dir.mktmpdir("m4a-config-") do |directory|
      path = File.join(directory, "reportportal.yml")
      File.write(path, <<~YAML)
        default:
          queue_max_records: 90
          queue_max_bytes: 9000
          batch_max_bytes: 8000
          queue_overflow_policy: reject_new
          queue_admission_timeout_ms: 90
        profiles:
          ci:
            queue_max_records: 80
            queue_max_bytes: 8000
            batch_max_bytes: 7000
            queue_overflow_policy: block
            queue_admission_timeout_ms: 80
      YAML

      config = described_class.load(
        profile: "ci",
        yaml_path: path,
        env: {
          "RP_QUEUE_MAX_RECORDS" => "70",
          "RP_QUEUE_MAX_BYTES" => "7000",
          "RP_BATCH_SIZE_LOGS" => "7",
          "RP_BATCH_MAX_BYTES" => "6000",
          "RP_QUEUE_OVERFLOW_POLICY" => "reject_new",
          "RP_QUEUE_ADMISSION_TIMEOUT_MS" => "70"
        },
        overrides: { queue_max_records: 60, queue_overflow_policy: :block }
      )

      expect(config.queue_max_records).to eq(60)
      expect(config.queue_max_bytes).to eq(7000)
      expect(config.batch_size_logs).to eq(7)
      expect(config.batch_max_bytes).to eq(6000)
      expect(config.queue_overflow_policy.to_s).to eq("block")
      expect(config.queue_admission_timeout_ms).to eq(70)
    end
  end

  it "rejects malformed limits and policies without echoing supplied values" do
    invalid_values = [0, -1, 2.5, true, false, nil, "not-a-number", "2.5"]
    %i[queue_max_records queue_max_bytes batch_size_logs batch_max_bytes queue_admission_timeout_ms].each do |key|
      invalid_values.each do |value|
        error = nil
        begin
          described_class.new(key => value)
        rescue ArgumentError => caught
          error = caught
        end

        expect(error).to be_a(ArgumentError), "#{key}=#{value.inspect} should be rejected"
        expect(error.message).not_to include(value.to_s) if error && !value.to_s.empty?
      end
    end

    ["discard_oldest", "secret-policy-value"].each do |value|
      error = nil
      begin
        described_class.new(queue_overflow_policy: value)
      rescue ArgumentError => caught
        error = caught
      end

      expect(error).to be_a(ArgumentError)
      expect(error.message).not_to include(value)
    end

    {
      "RP_QUEUE_MAX_RECORDS" => "not-a-number",
      "RP_QUEUE_MAX_BYTES" => "0",
      "RP_BATCH_MAX_BYTES" => "-5",
      "RP_QUEUE_ADMISSION_TIMEOUT_MS" => "2.5"
    }.each do |key, value|
      error = nil
      begin
        described_class.load(env: { key => value })
      rescue ArgumentError => caught
        error = caught
      end

      expect(error).to be_a(ArgumentError), "#{key} should reject malformed input"
      expect(error.message).not_to include(value)
    end
  end
end
