# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Runtime::Join do
  it "shares a single launch uuid across forked processes and creates it once" do
    Dir.mktmpdir do |dir|
      config = ReportportalCucumber::Config.new(
        endpoint: "https://rp.example.com",
        project: "demo",
        api_key: "token",
        join: true,
        join_lock_file_name: "rp.lock",
        join_sync_file_name: "rp-sync.json",
        join_wait_timeout_ms: 5_000
      )
      creator_path = File.join(dir, "creator.txt")
      result_paths = 2.times.map { |index| File.join(dir, "result-#{index}.txt") }

      pids = 2.times.map do |index|
        fork do
          join = described_class.new(config: config, cwd: dir)
          uuid = join.acquire_or_wait_launch_uuid do
            File.open(creator_path, "a") { |file| file.puts(Process.pid) }
            sleep(0.2) if index.zero?
            "shared-launch"
          end
          File.write(result_paths[index], JSON.generate({ uuid: uuid, primary: join.primary? }))
          exit!(0)
        end
      end

      pids.each { |pid| Process.wait(pid) }

      creators = File.read(creator_path).lines
      results = result_paths.map { |path| JSON.parse(File.read(path)) }

      expect(creators.length).to eq(1)
      expect(results.map { |row| row["uuid"] }).to eq(%w[shared-launch shared-launch])
      expect(results.count { |row| row["primary"] }).to eq(1)
    end
  end

  it "ignores stale sync files from dead processes" do
    Dir.mktmpdir do |dir|
      config = ReportportalCucumber::Config.new(
        endpoint: "https://rp.example.com",
        project: "demo",
        api_key: "token",
        launch: "fresh-launch",
        join: true,
        join_lock_file_name: "rp.lock",
        join_sync_file_name: "rp-sync.json",
        join_wait_timeout_ms: 5_000
      )

      File.write(
        File.join(dir, "rp-sync.json"),
        JSON.generate(
          launchUuid: "stale-launch",
          launchName: "fresh-launch",
          project: "demo",
          endpoint: "https://rp.example.com",
          pid: 999_999,
          writtenAt: Time.now.utc.iso8601
        )
      )

      join = described_class.new(config: config, cwd: dir)
      uuid = join.acquire_or_wait_launch_uuid { "fresh-launch-uuid" }

      expect(uuid).to eq("fresh-launch-uuid")
      expect(join).to be_primary
    end
  end
end
