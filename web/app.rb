# frozen_string_literal: true

require "sinatra/base"
require "json"
require_relative "../lib/livebarn_tools"
require_relative "../lib/livebarn_tools/job_store"

module LivebarnTools
  class WebApp < Sinatra::Base
    set :views, File.join(__dir__, "views")
    set :public_folder, File.join(__dir__, "public")

    JOBS = JobStore.new

    helpers do
      def job
        @job ||= JOBS.get(params[:id])
      end

      def halt_not_found
        halt 404, "Job not found"
      end

      def format_time(seconds)
        hours = (seconds / 3600).to_i
        mins  = ((seconds % 3600) / 60).to_i
        secs  = (seconds % 60).to_i
        format("%02d:%02d:%02d", hours, mins, secs)
      end

      # Extract arena prefix from a Livebarn filename.
      # e.g. "Kettle_Moraine_Ice_Center_Rink_1_2026-02-14T135956.mp4"
      #    → "Kettle_Moraine_Ice_Center_Rink_1"
      def extract_arena(filename)
        basename = File.basename(filename)
        match = basename.match(/\A(.+?)_\d{4}-\d{2}-\d{2}T/)
        match ? match[1] : nil
      end
    end

    # Step 1: Upload form
    get "/" do
      erb :index
    end

    # Handle upload + create job
    post "/upload" do
      team  = params[:team].to_s.strip
      files = Array(params[:files])

      if team.empty? || files.empty?
        @error = "Game title and at least one video file are required."
        return erb(:index)
      end

      # Detect arena prefix from the first uploaded filename
      first_name = files.find { |f| f.is_a?(Hash) && f[:filename] }&.dig(:filename) || ""
      arena = extract_arena(first_name)

      unless arena
        @error = "Could not detect arena from filenames. Expected Livebarn format: ArenaName_YYYY-MM-DDT*.mp4"
        return erb(:index)
      end

      job = JOBS.create(arena: arena, team: team)

      files.each do |uploaded|
        next unless uploaded.is_a?(Hash) && uploaded[:tempfile]
        safe_name = File.basename(uploaded[:filename])
        dest = File.join(job.work_dir, safe_name)
        FileUtils.cp(uploaded[:tempfile].path, dest)
      end

      JOBS.update(job.id, status: :concatenating)
      JOBS.push_message(job.id, "Uploaded #{files.length} file(s). Starting concatenation...")

      Thread.new do
        begin
          concatenator = Concatenator.new
          concat_file = concatenator.concat(arena, team, dir: job.work_dir)
          JOBS.update(job.id, concat_file: concat_file, status: :concat_done)
          JOBS.push_message(job.id, "done:concat")
        rescue => e
          JOBS.update(job.id, status: :error, error: e.message)
          JOBS.push_message(job.id, "error:#{e.message}")
        end
      end

      redirect "/progress/#{job.id}?next=trim"
    end

    # Progress page (SSE-driven)
    get "/progress/:id" do
      halt_not_found unless job
      @next_step = params[:next] || "trim"
      erb :progress
    end

    # SSE endpoint
    get "/progress/:id/events" do
      halt_not_found unless JOBS.get(params[:id])

      content_type "text/event-stream"
      cache_control :no_cache

      stream(:keep_open) do |out|
        index = 0
        loop do
          messages = JOBS.messages_since(params[:id], index)
          messages.each do |msg|
            out << "data: #{msg}\n\n"
            index += 1
          end
          sleep 0.5
          break if out.closed?
          j = JOBS.get(params[:id])
          break if j.nil? || j.status == :error
          break if msg_done?(messages)
        end
      end
    end

    # Step 3: Trim page
    get "/trim/:id" do
      halt_not_found unless job
      @duration = Trimmer.new.probe_duration(job.concat_file)
      erb :trim
    end

    # Serve video file for HTML5 player
    get "/video/:id" do
      halt_not_found unless job
      video_path = job.trimmed_file || job.concat_file
      halt 404, "No video available" unless video_path && File.exist?(video_path)
      send_file video_path, type: "video/mp4", disposition: "inline"
    end

    # Handle trim submission
    post "/trim/:id" do
      halt_not_found unless job
      front_trim   = params[:front_trim].to_s.strip
      end_trim     = params[:end_trim].to_s.strip
      remove_audio = params[:remove_audio] == "1"

      front_trim = "0" if front_trim.empty?
      end_trim   = "0" if end_trim.empty?

      JOBS.update(job.id, status: :trimming)
      JOBS.push_message(job.id, "Trimming video (front: #{front_trim}, end: #{end_trim}#{", removing audio" if remove_audio})...")

      Thread.new do
        begin
          trimmer = Trimmer.new
          trimmed = trimmer.trim(job.concat_file, front_trim, end_trim, dir: job.work_dir, remove_audio: remove_audio)
          JOBS.update(job.id, trimmed_file: trimmed, status: :trim_done)
          JOBS.push_message(job.id, "done:trim")
        rescue => e
          JOBS.update(job.id, status: :error, error: e.message)
          JOBS.push_message(job.id, "error:#{e.message}")
        end
      end

      redirect "/progress/#{job.id}?next=output"
    end

    # Step 4: Output page
    get "/output/:id" do
      halt_not_found unless job
      erb :output
    end

    # Download trimmed file
    get "/download/:id" do
      halt_not_found unless job
      file = job.trimmed_file || job.concat_file
      halt 404, "No file available" unless file && File.exist?(file)
      send_file file, type: "video/mp4", disposition: "attachment",
                filename: File.basename(file)
    end

    # YouTube upload
    post "/upload_youtube/:id" do
      halt_not_found unless job
      title       = params[:title].to_s.strip
      description = params[:description].to_s.strip
      season      = params[:season].to_s.strip
      season      = nil if season.empty?

      if title.empty?
        @error = "Title is required."
        return erb(:output)
      end

      file = job.trimmed_file || job.concat_file
      halt 404, "No file available" unless file && File.exist?(file)

      JOBS.update(job.id, status: :uploading)
      JOBS.push_message(job.id, "Uploading to YouTube...")

      Thread.new do
        begin
          uploader = Uploader.new
          url = uploader.upload(file: file, title: title, description: description, season: season)
          JOBS.push_message(job.id, "done:upload:#{url}")
          JOBS.update(job.id, status: :upload_done)
        rescue => e
          JOBS.update(job.id, status: :error, error: e.message)
          JOBS.push_message(job.id, "error:#{e.message}")
        end
      end

      redirect "/progress/#{job.id}?next=upload_done"
    end

    # Upload done page
    get "/upload_done/:id" do
      halt_not_found unless job
      erb :upload_done
    end

    private

    def msg_done?(messages)
      messages.any? { |m| m.start_with?("done:") || m.start_with?("error:") }
    end
  end
end
