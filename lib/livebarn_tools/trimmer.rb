# frozen_string_literal: true

require "open3"

module LivebarnTools
  class Trimmer
    def trim(input_path, front_trim, end_trim)
      duration = probe_duration(input_path)

      front_sec = to_seconds(front_trim)
      end_sec = to_seconds(end_trim)
      new_duration = duration - front_sec - end_sec

      if new_duration <= 0
        raise LivebarnTools::Error, "Trim times are longer than video duration"
      end

      output_file = trimmed_filename(input_path)

      _out, err, status = Open3.capture3(
        "ffmpeg", "-ss", front_trim.to_s, "-i", input_path,
        "-t", new_duration.to_s, "-c", "copy", output_file
      )

      unless status.success?
        raise LivebarnTools::Error, "ffmpeg trim failed: #{err}"
      end

      puts "Trimmed video saved as: #{output_file}"
      output_file
    end

    def probe_duration(path)
      out, err, status = Open3.capture3(
        "ffprobe", "-i", path, "-show_entries", "format=duration",
        "-v", "quiet", "-of", "csv=p=0"
      )

      unless status.success?
        raise LivebarnTools::Error, "ffprobe failed: #{err}"
      end

      duration = out.strip.to_f
      if duration <= 0
        raise LivebarnTools::Error, "Could not determine duration of #{path}"
      end

      duration
    end

    def to_seconds(time_str)
      str = time_str.to_s.strip
      unless str.match?(/\A\d+(\.\d+)?(:\d{1,2}(\.\d+)?){0,2}\z/)
        raise LivebarnTools::Error, "Invalid time format '#{str}': use HH:MM:SS, MM:SS, or seconds"
      end

      parts = str.split(":")
      case parts.length
      when 3
        parts[0].to_f * 3600 + parts[1].to_f * 60 + parts[2].to_f
      when 2
        parts[0].to_f * 60 + parts[1].to_f
      else
        parts[0].to_f
      end
    end

    def trimmed_filename(input_path)
      basename = File.basename(input_path, ".mp4")
      "#{basename}_trimmed.mp4"
    end
  end
end
