# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe LivebarnTools::Trimmer do
  let(:trimmer) { described_class.new }

  describe "#to_seconds" do
    it "converts HH:MM:SS" do
      expect(trimmer.to_seconds("01:30:00")).to eq(5400.0)
    end

    it "converts MM:SS" do
      expect(trimmer.to_seconds("12:30")).to eq(750.0)
    end

    it "converts bare seconds" do
      expect(trimmer.to_seconds("45")).to eq(45.0)
    end

    it "converts fractional seconds" do
      expect(trimmer.to_seconds("1.5")).to eq(1.5)
    end

    it "converts HH:MM:SS with fractional seconds" do
      expect(trimmer.to_seconds("00:01:30.5")).to eq(90.5)
    end
  end

  describe "#trimmed_filename" do
    it "appends _trimmed to the basename" do
      expect(trimmer.trimmed_filename("game.mp4")).to eq("game_trimmed.mp4")
    end

    it "strips directory from input path" do
      expect(trimmer.trimmed_filename("/some/path/game.mp4")).to eq("game_trimmed.mp4")
    end
  end

  describe "#probe_duration" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    context "with a real video file" do
      before do
        @video = File.join(@tmpdir, "test.mp4")
        system(
          "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=2x2:d=2",
          "-c:v", "libx264", "-t", "2",
          @video,
          err: File::NULL, out: File::NULL
        )
      end

      it "returns the duration as a float" do
        duration = trimmer.probe_duration(@video)
        expect(duration).to be_within(0.5).of(2.0)
      end
    end
  end

  describe "#trim" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        Dir.chdir(dir) { example.run }
      end
    end

    context "with a real video file" do
      before do
        @video = File.join(@tmpdir, "test_video.mp4")
        system(
          "ffmpeg", "-y", "-f", "lavfi", "-i", "nullsrc=s=2x2:d=2",
          "-c:v", "libx264", "-t", "2",
          @video,
          err: File::NULL, out: File::NULL
        )
      end

      it "trims front and end of a video" do
        output = trimmer.trim(@video, "0.5", "0.5")
        expect(output).to eq("test_video_trimmed.mp4")
        expect(File.exist?(output)).to be true
      end

      it "raises an error when trim exceeds duration" do
        expect {
          trimmer.trim(@video, "00:01:00", "00:01:00")
        }.to raise_error(LivebarnTools::Error, /Trim times are longer than video duration/)
      end
    end
  end
end
