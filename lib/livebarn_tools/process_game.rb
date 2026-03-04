# frozen_string_literal: true

require "optparse"

module LivebarnTools
  class ProcessGame
    def initialize(concatenator: Concatenator.new, trimmer: Trimmer.new, uploader: Uploader.new)
      @concatenator = concatenator
      @trimmer = trimmer
      @uploader = uploader
    end

    def run(argv)
      options = parse_args(argv)
      process(**options)
    end

    def parse_args(argv)
      options = { cleanup: true, upload: true, remove_audio: false }

      parser = OptionParser.new do |opts|
        opts.on("--season SEASON")  { |v| options[:season] = v }
        opts.on("--title TITLE")    { |v| options[:title] = v }
        opts.on("--no-cleanup")     { options[:cleanup] = false }
        opts.on("--no-audio")       { options[:remove_audio] = true }
        opts.on("--skip-upload")    { options[:upload] = false }
        opts.on("-h", "--help")     { puts usage; exit 0 }
      end

      positional = parser.parse(argv)

      unless positional.length == 4
        raise LivebarnTools::Error,
          "expected 4 positional arguments, got #{positional.length}\n\n#{usage}"
      end

      options[:arena] = positional[0]
      options[:team] = positional[1]
      options[:front_trim] = positional[2]
      options[:end_trim] = positional[3]

      if options[:upload] && !options[:season]
        raise LivebarnTools::Error, "--season is required (or use --skip-upload)"
      end

      options
    end

    def process(arena:, team:, front_trim:, end_trim:, season: nil, title: nil, upload: true, cleanup: true, remove_audio: false)
      # Step 1: Concatenate
      puts "==> Step 1: Concatenating video segments..."
      concat_file = @concatenator.concat(arena, team)
      puts "    Concatenated: #{concat_file}"

      # Step 2: Trim
      puts ""
      puts "==> Step 2: Trimming video..."
      trimmed_file = @trimmer.trim(concat_file, front_trim, end_trim, remove_audio: remove_audio)
      puts "    Trimmed: #{trimmed_file}"

      # Auto-generate title if not provided
      if title.nil? || title.empty?
        date_part = File.basename(concat_file).match(/^(\d{4}-\d{2}-\d{2})_/)&.[](1)
        title = "#{date_part} #{team}"
      end

      # Step 3: Upload
      if upload
        puts ""
        puts "==> Step 3: Uploading to YouTube..."
        @uploader.upload(file: trimmed_file, title: title, description: "", season: season)
      else
        puts ""
        puts "==> Step 3: Upload skipped (--skip-upload)"
      end

      # Step 4: Cleanup
      if cleanup && concat_file != trimmed_file
        File.delete(concat_file)
        puts ""
        puts "Cleaned up intermediate file: #{concat_file}"
      end

      puts ""
      puts "Done! Final video: #{trimmed_file}"
      trimmed_file
    end

    private

    def usage
      <<~USAGE
        Usage: process_game <arena_name> <team_name> <front_trim> <end_trim> --season SEASON [--title TITLE] [--no-cleanup] [--no-audio]

        All-in-one Livebarn game processing: concatenate segments, trim, and
        upload to YouTube.

        Steps performed:
          1. Concatenate arena segments (concat_videos)
          2. Trim front and end of the recording (trim_video)
          3. Upload trimmed video to YouTube as unlisted (upload_youtube)
          4. Add to a season playlist
          5. Clean up intermediate concatenated file (unless --no-cleanup)

        Arguments:
          arena_name    Name of the arena (matches {arena_name}_*.mp4)
          team_name     Team name for the output filename
          front_trim    Time to trim from the start (e.g., 00:12:00)
          end_trim      Time to trim from the end (e.g., 00:15:00)

        Options:
          --season SEASON   Season playlist name (required for upload)
          --title TITLE     Video title; if omitted, auto-generated as
                            "{date} {team_name}"
          --no-cleanup      Keep the intermediate concatenated file
          --no-audio        Remove audio track from the trimmed video
          --skip-upload     Skip the YouTube upload step
          -h, --help        Show this help

        Example:
          process_game main-court tigers 00:12:00 00:05:00 --season "Spring 2026"
          process_game main-court tigers 00:12:00 00:05:00 --season "Spring 2026" --title "vs Hawks - Mar 1"
      USAGE
    end
  end
end
