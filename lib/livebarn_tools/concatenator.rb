# frozen_string_literal: true

require "open3"
require "tempfile"

module LivebarnTools
  class Concatenator
    def concat(arena_name, team_name, dir: Dir.pwd)
      segments = find_segments(arena_name, dir)

      if segments.empty?
        raise LivebarnTools::Error, "No matching files found for arena name '#{arena_name}' in #{dir}."
      end

      date = extract_date(segments.first)
      output_file = File.join(dir, "#{date}_#{team_name}.mp4")

      Tempfile.create(["file_list", ".txt"], dir) do |f|
        segments.each { |s| f.puts "file '#{s}'" }
        f.flush

        _out, err, status = Open3.capture3(
          "ffmpeg", "-f", "concat", "-safe", "0", "-i", f.path, "-c", "copy", output_file
        )

        unless status.success?
          raise LivebarnTools::Error, "ffmpeg concat failed: #{err}"
        end
      end

      puts "Videos concatenated into: #{output_file}"
      output_file
    end

    def find_segments(arena_name, dir)
      Dir.glob(File.join(dir, "#{arena_name}_*.mp4")).sort
    end

    def extract_date(filename)
      basename = File.basename(filename)
      match = basename.match(/(\d{4}-\d{2}-\d{2})T/)
      raise LivebarnTools::Error, "Could not extract date from filename: #{basename}" unless match

      match[1]
    end
  end
end
