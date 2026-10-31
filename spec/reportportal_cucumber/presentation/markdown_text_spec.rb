# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReportportalCucumber::Presentation::MarkdownText do
  it "escapes entities once and distinguishes input HTML from trusted breaks" do
    expect(described_class.html('<other>&amp;')).to eq('&lt;other&gt;&amp;amp;')
    expect(described_class.cell("<br>\\|\r\nx\ry\nz")).to eq("&lt;br&gt;\\\\\\|<br>x<br>y<br>z")
  end

  it "escapes inline punctuation and leading Markdown without escaping code" do
    expect(described_class.inline("# <x> *a* _b_ [c] | ~d~ `e`\\\nnext"))
      .to eq("\\# &lt;x&gt; \\*a\\* \\_b\\_ \\[c\\] \\| \\~d\\~ \\`e\\`\\\\ next")
    expect(described_class.inline("12. item")).to eq("12\\. item")
    expect(described_class.inline("+ item")).to eq("\\+ item")
    expect(described_class.inline("> quote")).to eq("&gt; quote")
    expect(described_class.code("<x>&")).to eq("`<x>&`")
    expect(described_class.code("`x`\t\0")).to eq("`` `x` ``")
    expect(described_class.code("")).to eq("`(empty)`")
    expect(described_class.fence("<x>&", "text")).to eq("```text\n<x>&\n```")
  end

  it "uses bounded safe fences or signals omission, without altering fence content" do
    expect(described_class.fence("```\nx", "text")).to eq("````text\n```\nx\n````")
    expect(described_class.fence("`" * 32, "text")).to eq("~~~text\n#{'`' * 32}\n~~~")
    expect(described_class.fence("`" * 32 + "~" * 32, "text")).to be_nil
    expect(described_class.fence("safe", "text\n<script>")).to eq("```\nsafe\n```")
  end

  it "is deterministic, valid UTF-8, bounded and structurally safe for 1,000 generated inputs per method" do
    random = Random.new(231)
    alphabet = ["<", ">", "&", "|", "\\", "`", "*", "_", "[", "]", "#", "~", "\r", "\n", "\t", "\0",
                "\u{1f7e2}", "\u4e2d", "\xFF".b, "a"]
    1000.times do
      input = Array.new(random.rand(0..180)) { alphabet.sample(random: random).b }.join.force_encoding(Encoding::UTF_8).freeze
      %i[html cell inline code fence].each do |method|
        output = described_class.public_send(method, input)
        expect(output).to eq(described_class.public_send(method, input))
        next if output.nil?

        expect(output).to be_valid_encoding
        expect(output.bytesize).to be <= 6 * described_class::INPUT_LIMIT
        if %i[html cell inline].include?(method)
          expect(output.gsub('<br>', '')).not_to match(/[<>]/)
        end
        if method == :cell
          expect(output).not_to match(/[\r\n]/)
          expect(output.gsub(/\\./m, '')).not_to include('|')
        elsif method == :code
          delimiter = output[/\A`+/]
          body = output[delimiter.length...-delimiter.length]
          expect(body.scan(/`+/).map(&:length).max || 0).to be < delimiter.length
        elsif method == :fence
          delimiter = output.lines.first.strip
          expect(delimiter.length).to be <= 32
          expect(output.lines.last.strip).to eq(delimiter)
          body = output.lines[1...-1].join
          expect(body.scan(/#{Regexp.escape(delimiter[0])}+/).map(&:length).max || 0).to be < delimiter.length
        end
      end
    end
  end

  it "bounds hostile input and does not invoke arbitrary object conversion" do
    hostile = Object.new
    def hostile.to_s
      raise "do not call"
    end
    %i[html cell inline code fence].each do |method|
      expect { described_class.public_send(method, hostile) }.not_to raise_error
      output = described_class.public_send(method, "\xFF".b * 1_000_000)
      expect(output).to be_valid_encoding
      expect(output.bytesize).to be <= 6 * described_class::INPUT_LIMIT
    end
  end
end
