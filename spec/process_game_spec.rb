# frozen_string_literal: true

require "spec_helper"

RSpec.describe LivebarnTools::ProcessGame do
  let(:concatenator) { instance_double(LivebarnTools::Concatenator) }
  let(:trimmer) { instance_double(LivebarnTools::Trimmer) }
  let(:uploader) { instance_double(LivebarnTools::Uploader) }
  let(:processor) do
    described_class.new(concatenator: concatenator, trimmer: trimmer, uploader: uploader)
  end

  describe "#parse_args" do
    it "parses valid arguments with all options" do
      args = %w[arena team 00:12:00 00:05:00 --season Spring\ 2026 --title My\ Game]
      result = processor.parse_args(args)

      expect(result[:arena]).to eq("arena")
      expect(result[:team]).to eq("team")
      expect(result[:front_trim]).to eq("00:12:00")
      expect(result[:end_trim]).to eq("00:05:00")
      expect(result[:season]).to eq("Spring 2026")
      expect(result[:title]).to eq("My Game")
      expect(result[:upload]).to be true
      expect(result[:cleanup]).to be true
    end

    it "parses --no-cleanup flag" do
      args = %w[arena team 00:12:00 00:05:00 --season x --no-cleanup]
      result = processor.parse_args(args)
      expect(result[:cleanup]).to be false
    end

    it "parses --skip-upload flag" do
      args = %w[arena team 00:12:00 00:05:00 --skip-upload]
      result = processor.parse_args(args)
      expect(result[:upload]).to be false
    end

    it "raises error with wrong number of positional arguments" do
      expect {
        processor.parse_args(%w[arena team])
      }.to raise_error(LivebarnTools::Error, /expected 4 positional arguments, got 2/)
    end

    it "raises error when --season is missing and upload enabled" do
      expect {
        processor.parse_args(%w[arena team 00:12:00 00:05:00])
      }.to raise_error(LivebarnTools::Error, /--season is required/)
    end

    it "does not require --season when --skip-upload is set" do
      result = processor.parse_args(%w[arena team 00:12:00 00:05:00 --skip-upload])
      expect(result[:upload]).to be false
    end

    it "exits 0 on --help" do
      expect {
        processor.parse_args(["--help"])
      }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end
  end

  describe "#process" do
    before do
      allow(concatenator).to receive(:concat).and_return("2026-03-01_tigers.mp4")
      allow(trimmer).to receive(:trim).and_return("2026-03-01_tigers_trimmed.mp4")
      allow(uploader).to receive(:upload).and_return("https://youtu.be/abc123")
      allow(File).to receive(:delete)
    end

    it "calls concatenator, trimmer, and uploader in order" do
      expect(concatenator).to receive(:concat).with("arena", "tigers").ordered
      expect(trimmer).to receive(:trim).with("2026-03-01_tigers.mp4", "00:12:00", "00:05:00", remove_audio: false).ordered
      expect(uploader).to receive(:upload).with(
        file: "2026-03-01_tigers_trimmed.mp4",
        title: "2026-03-01 tigers",
        description: "",
        season: "Spring 2026"
      ).ordered

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        season: "Spring 2026"
      )
    end

    it "auto-generates title from date and team name" do
      expect(uploader).to receive(:upload).with(
        hash_including(title: "2026-03-01 tigers")
      )

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        season: "Spring 2026"
      )
    end

    it "uses provided title when given" do
      expect(uploader).to receive(:upload).with(
        hash_including(title: "vs Hawks - Mar 1")
      )

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        season: "Spring 2026", title: "vs Hawks - Mar 1"
      )
    end

    it "skips upload when upload is false" do
      expect(uploader).not_to receive(:upload)

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        upload: false
      )
    end

    it "cleans up intermediate file by default" do
      expect(File).to receive(:delete).with("2026-03-01_tigers.mp4")

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        upload: false
      )
    end

    it "skips cleanup when cleanup is false" do
      expect(File).not_to receive(:delete)

      processor.process(
        arena: "arena", team: "tigers",
        front_trim: "00:12:00", end_trim: "00:05:00",
        upload: false, cleanup: false
      )
    end
  end
end
