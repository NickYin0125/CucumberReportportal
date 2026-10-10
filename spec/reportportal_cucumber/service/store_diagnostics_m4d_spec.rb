# frozen_string_literal: true

require "spec_helper"

RSpec.describe "M4 Store public diagnostic taxonomy" do
  let(:directory) { Dir.mktmpdir("m4d-store-diagnostics-private-") }
  let(:config) do
    ReportportalCucumber::Config.new(
      endpoint: "https://diagnostics.example.test", project: "synthetic", api_key: "DIAGNOSTIC_AUTH_SECRET",
      spool_dir: File.join(directory, "spool"), exit_flush_timeout_ms: 2_000
    )
  end
  let(:store) { ReportportalCucumber::Service::SpoolStore.new(config: config) }
  let(:entry) do
    { "launchUuid" => "11111111-1111-4111-8111-111111111111",
      "itemUuid" => "22222222-2222-4222-8222-222222222222", "time" => "1791590400000",
      "message" => "DIAGNOSTIC_PAYLOAD_SECRET", "level" => "info", "file" => { "name" => "private-evidence.bin" } }
  end
  let(:bytes) { "\x00\xFF\xFEprivate-binary-evidence".b }
  let(:id) do
    store.persist(entries: [entry], files: [{ name: "private-evidence.bin", mime: "application/octet-stream", bytes: bytes }],
                  outcome: :failed)
  end
  let(:transaction) { store.load_transaction(id: id) }
  let(:blob) { transaction.fetch(:files).fetch(0).fetch(:path) }

  after { FileUtils.remove_entry(directory) if File.exist?(directory) }

  def expect_loader_reason(reason)
    expect { store.load_transaction(id: id) }.to raise_error(ReportportalCucumber::Service::SpoolStore::Error) do |error|
      expect(error.reason).to be_a(Symbol)
      expect(error.reason).to eq(reason)
      expect(error.message).to eq("Spool transaction unavailable")
      expect(error.message).not_to include(directory, id, "private-evidence.bin", "DIAGNOSTIC_AUTH_SECRET",
                                           "DIAGNOSTIC_PAYLOAD_SECRET", bytes)
    end
  end

  it "reports a deleted physical attachment as missing_attachment, not a missing transaction" do
    path = blob
    File.delete(path)

    expect_loader_reason(:missing_attachment)
    expect(File.file?(File.join(config.spool_dir, "#{id}.ndjson"))).to be(true)
  end

  it "also classifies an attachment disappearing between validation and open without leaking the OS path" do
    path = blob
    flags = File::RDONLY | (File.const_defined?(:NOFOLLOW) ? File::NOFOLLOW : 0)
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(path, flags).and_raise(Errno::ENOENT.new("PRIVATE_OS_PATH_SECRET #{path}"))

    expect_loader_reason(:missing_attachment)
  end

  { shorter: ->(original) { original.byteslice(0, original.bytesize - 1) },
    longer: ->(original) { original + "x" },
    same_length_wrong_hash: ->(original) { "x".b * original.bytesize } }.each do |kind, replacement|
    it "keeps #{kind} attachment content classified as corrupt_attachment" do
      path = blob
      File.binwrite(path, replacement.call(bytes))

      expect_loader_reason(:corrupt_attachment)
    end
  end

  %w[.manifest.json .checkpoint.json .entries.ndjson publication_marker transaction_directory].each do |component|
    it "keeps missing #{component} classified as missing_transaction" do
      txdir = transaction.fetch(:directory)
      case component
      when "publication_marker"
        File.delete(File.join(config.spool_dir, "#{id}.ndjson"))
      when "transaction_directory"
        FileUtils.remove_entry(txdir)
      else
        File.delete(File.join(txdir, component))
      end

      expect_loader_reason(:missing_transaction)
    end
  end

  it "loads deliberate source_unavailable metadata without inventing an empty healthy attachment" do
    missing_path = File.join(directory, "never-published-source.bin")
    unavailable_id = store.persist(
      entries: [entry], files: [{ name: "private-evidence.bin", mime: "application/octet-stream", path: missing_path }],
      outcome: :failed
    )
    loaded = store.load_transaction(id: unavailable_id)
    file = loaded.fetch(:files).fetch(0)

    expect(loaded.fetch(:entries)).to eq([entry])
    expect(file).to include(name: "private-evidence.bin", mime: "application/octet-stream", entry_index: 0,
                           unavailable: true, reason: "source_unavailable")
    expect(file).not_to have_key(:length)
    expect(file).not_to have_key(:sha256)
    expect(File.exist?(File.join(loaded.fetch(:directory), file.fetch(:path)))).to be(false)
    expect(loaded.fetch(:checkpoint).fetch("states")).to eq([{ "state" => "pending" }])
    expect(store.transactions).to include(unavailable_id)
  end
end
