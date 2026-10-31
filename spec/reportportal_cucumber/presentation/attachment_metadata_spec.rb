# frozen_string_literal: true

require "spec_helper"
require "reportportal_cucumber/presentation/attachment_caption"

RSpec.describe "Ledger attachment metadata" do
  let(:dimensions) { ReportportalCucumber::Presentation::ImageDimensions }
  let(:caption) { ReportportalCucumber::Presentation::AttachmentCaption }
  let(:png) { "\x89PNG\r\n\x1a\n".b + [13].pack("N") + "IHDR" + [640, 360].pack("NN") + "\x08\x02\x00\x00\x00".b }

  def jpeg(marker = 0xc0, width: 754, height: 790)
    "\xff\xd8\xff".b + [marker].pack("C") + [11].pack("n") + [8, height, width, 1, 1, 0x11, 0].pack("CnnCCCC") + "\xff\xd9".b
  end

  it "matches the PNG golden without changing binary bytes" do
    before = png.dup.freeze
    expect(caption.format(name: "visible-fixture.png", mime: "image/png", size: 5421, header: png)).to eq("`visible-fixture.png` · PNG · 640 × 360 · 5.3 KB")
    expect(png).to eq(before)
  end

  it "matches the JPEG golden and supports progressive SOF2" do
    [0xc0, 0xc2].each do |marker|
      expect(caption.format(name: "after-failure.jpg", mime: "image/jpeg", size: 36612, header: jpeg(marker))).to eq("`after-failure.jpg` · JPEG · 754 × 790 · 36 KB")
    end
  end

  it "matches text and JSON caption goldens" do
    expect(caption.format(name: "visible-fixture.txt", mime: "text/plain", size: 71, lines: 2)).to eq("`visible-fixture.txt` · Text · 2 lines · 71 B")
    expect(caption.format(name: "visible-fixture.json", mime: "application/json", size: 75)).to eq("`visible-fixture.json` · JSON · 75 B")
  end

  it "marks failure evidence without inserting a duplicate client prefix" do
    expect(caption.format(name: "evidence.json", mime: "application/json", size: 2, evidence: true)).to eq("`evidence.json` · JSON · 2 B · failure evidence")
  end

  it "labels declared MIME without guessing from content or suffix" do
    expect(caption.format(name: "looks-like.png", mime: "text/plain", size: png.bytesize, header: png)).not_to include("640 × 360")
    expect(caption.format(name: "negative.png", mime: "image/png", size: 4, header: "AAAA")).to eq("`negative.png` · PNG · 4 B")
    expect(caption.kind("application/vnd.api+json; charset=utf-8")).to eq("JSON")
    expect(caption.kind("application/octet-stream")).to eq("File")
    expect(caption.kind("video/webm")).to eq("WebM")
  end

  it "does not report dimensions for malformed or truncated headers" do
    ["", "random", png.byteslice(0, 20), jpeg.byteslice(0, 9)].each do |data|
      expect(dimensions.read(data, mime: "image/png")).to be_nil
      expect(dimensions.read(data, mime: "image/jpeg")).to be_nil
    end
    expect(dimensions.read(jpeg(width: 0), mime: "image/jpeg")).to be_nil
  end

  it "stops JPEG inspection at the scan data and at 64 KiB" do
    expect(dimensions.read("\xff\xd8\xff\xda".b + jpeg, mime: "image/jpeg")).to be_nil
    oversized_app = "\xff\xd8\xff\xe0".b + [65535].pack("n") + ("x" * 65533) + jpeg.byteslice(2..)
    expect(dimensions.read(oversized_app, mime: "image/jpeg")).to be_nil
  end

  it "scans JPEG metadata segments without decoding the image" do
    prefix = "\xff\xd8\xff\xe0".b + [6].pack("n") + "JFIF"
    expect(dimensions.read(prefix + jpeg(0xc2).byteslice(2..), mime: "image/jpeg")).to eq([754, 790])
  end

  it "uses bounded deterministic ASCII slugs" do
    expect(caption.slug("Then the order is confirmed")).to eq("then-the-order-is-confirmed")
    expect(caption.slug("After hook")).to eq("after-hook")
    expect(caption.slug("中文")).to eq("attachment")
    expect(caption.slug("a" * 100)).to eq("a" * 48)
    expect(caption.slug("--- with punctuation?! ---")).to eq("with-punctuation")
  end
end
