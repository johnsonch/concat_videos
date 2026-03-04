# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe LivebarnTools::Concatenator do
  let(:concatenator) { described_class.new }

  describe "#find_segments" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "returns sorted matching files" do
      FileUtils.touch(File.join(@tmpdir, "rink_2026-03-01T10-00-00.mp4"))
      FileUtils.touch(File.join(@tmpdir, "rink_2026-03-01T10-30-00.mp4"))
      FileUtils.touch(File.join(@tmpdir, "rink_2026-03-01T09-30-00.mp4"))
      FileUtils.touch(File.join(@tmpdir, "other_2026-03-01T10-00-00.mp4"))

      segments = concatenator.find_segments("rink", @tmpdir)
      expect(segments.length).to eq(3)
      expect(segments).to eq(segments.sort)
      segments.each { |s| expect(File.basename(s)).to start_with("rink_") }
    end

    it "returns empty array when no files match" do
      segments = concatenator.find_segments("nonexistent", @tmpdir)
      expect(segments).to be_empty
    end
  end

  describe "#extract_date" do
    it "extracts date from a standard filename" do
      date = concatenator.extract_date("rink_2026-03-01T10-00-00.mp4")
      expect(date).to eq("2026-03-01")
    end

    it "extracts date from a full path" do
      date = concatenator.extract_date("/some/path/rink_2026-12-25T08-30-00.mp4")
      expect(date).to eq("2026-12-25")
    end

    it "raises an error when no date is found" do
      expect {
        concatenator.extract_date("no_date_here.mp4")
      }.to raise_error(LivebarnTools::Error, /Could not extract date/)
    end
  end

  describe "#concat" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "raises an error when no segments are found" do
      expect {
        concatenator.concat("nonexistent", "team", dir: @tmpdir)
      }.to raise_error(LivebarnTools::Error, /No matching files found/)
    end

    context "with real video segments" do
      before do
        system(
          "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=2x2:d=0.1",
          "-c:v", "libx264", "-t", "0.1",
          File.join(@tmpdir, "rink_2026-03-01T10-00-00.mp4"),
          err: File::NULL, out: File::NULL
        )
        system(
          "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=2x2:d=0.1",
          "-c:v", "libx264", "-t", "0.1",
          File.join(@tmpdir, "rink_2026-03-01T10-30-00.mp4"),
          err: File::NULL, out: File::NULL
        )
      end

      it "concatenates segments into a dated output file" do
        output = concatenator.concat("rink", "tigers", dir: @tmpdir)
        expect(output).to eq(File.join(@tmpdir, "2026-03-01_tigers.mp4"))
        expect(File.exist?(output)).to be true
        expect(File.size(output)).to be > 0
      end
    end
  end
end
