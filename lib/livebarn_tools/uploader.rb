# frozen_string_literal: true

require "optparse"
require "fileutils"
require "yaml"
require "json"
require "socket"
require "timeout"
require "securerandom"
require "net/http"
require "uri"
require "google/apis/youtube_v3"
require "googleauth"
require "signet/oauth_2/client"

module LivebarnTools
  class Uploader
    CONFIG_DIR  = File.expand_path("~/.config/livebarn_tools")
    SECRET_PATH = File.join(CONFIG_DIR, "client_secret.json")
    TOKEN_PATH  = File.join(CONFIG_DIR, "tokens.yaml")
    SCOPE       = Google::Apis::YoutubeV3::AUTH_YOUTUBE

    def run(argv)
      options = parse_args(argv)
      upload(
        file:        options[:file],
        title:       options[:title],
        description: options[:description],
        season:      options[:season]
      )
    end

    def upload(file:, title:, description: "", season: nil)
      client  = authorize
      service = build_service(client)

      video = upload_video(service, file, title, description)
      video_id = video.id
      video_url = "https://youtu.be/#{video_id}"

      if season
        playlist = find_or_create_playlist(service, season)
        add_to_playlist(service, playlist.id, video_id)
        puts "Added to playlist: #{season}"
      end

      puts ""
      puts "Video URL: #{video_url}"
      video_url
    end

    def usage
      puts <<~USAGE
        Usage: upload_youtube <video_file> --title TITLE [--season SEASON] [--description DESC]

        Upload a video to YouTube as unlisted and optionally add it to a
        season playlist.

        Options:
          --title TITLE          Video title (required)
          --season SEASON        Find or create an unlisted playlist with this name
                                 and add the video to it
          --description DESC     Video description (default: empty)
          -h, --help             Show this help

        Configuration:
          Place your Google OAuth client_secret.json at:
            #{SECRET_PATH}

          On first run, a browser window will open for Google authorization.
          The refresh token is stored at:
            #{TOKEN_PATH}

        Example:
          upload_youtube game.mp4 --title "vs Tigers - Mar 1" --season "Spring 2026"
      USAGE
    end

    def parse_args(argv)
      options = { description: "" }

      parser = OptionParser.new do |opts|
        opts.on("--title TITLE")             { |v| options[:title] = v }
        opts.on("--season SEASON")           { |v| options[:season] = v }
        opts.on("--description DESC")        { |v| options[:description] = v }
        opts.on("-h", "--help")              { usage; exit 0 }
      end

      remaining = parser.parse(argv)
      options[:file] = remaining.first

      unless options[:file]
        raise LivebarnTools::Error, "video file is required"
      end

      unless File.exist?(options[:file])
        raise LivebarnTools::Error, "file not found: #{options[:file]}"
      end

      unless options[:title]
        raise LivebarnTools::Error, "--title is required"
      end

      options
    end

    def load_client_secret(path = SECRET_PATH)
      unless File.exist?(path)
        raise LivebarnTools::Error,
          "client_secret.json not found at #{path}\nRun 'make setup' for configuration instructions."
      end

      mode = File.stat(path).mode & 0o777
      if mode != 0o600
        warn "WARNING: #{path} has permissions #{format('%04o', mode)}, expected 0600. " \
             "Fix with: chmod 600 #{path}"
      end

      raw = JSON.parse(File.read(path))
      cred = raw["installed"] || raw["web"]
      unless cred
        raise LivebarnTools::Error, "invalid client_secret.json format"
      end
      cred
    end

    def authorize(secret_path: SECRET_PATH, token_path: TOKEN_PATH)
      cred = load_client_secret(secret_path)

      client = Signet::OAuth2::Client.new(
        client_id:     cred["client_id"],
        client_secret: cred["client_secret"],
        scope:         SCOPE,
        redirect_uri:  "http://localhost:0",
        authorization_uri: cred["auth_uri"]  || "https://accounts.google.com/o/oauth2/auth",
        token_credential_uri: cred["token_uri"] || "https://oauth2.googleapis.com/token"
      )

      if File.exist?(token_path)
        saved = YAML.safe_load(File.read(token_path))
        client.refresh_token = saved["refresh_token"]
        client.access_token  = saved["access_token"]
        client.expires_at    = Time.parse(saved["expires_at"]) if saved["expires_at"]

        if client.expired?
          client.fetch_access_token!
          save_token(client, token_path)
        end

        return client
      end

      # No saved token — run OAuth loopback flow
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      client.redirect_uri = "http://127.0.0.1:#{port}"

      state = SecureRandom.hex(16)
      client.state = state
      auth_url = client.authorization_uri.to_s
      puts "Opening browser for Google authorization..."
      system("open", auth_url) || system("xdg-open", auth_url) || (
        puts "Open this URL in your browser:\n  #{auth_url}"
      )

      begin
        conn = Timeout.timeout(120) { server.accept }
      rescue Timeout::Error
        server.close
        raise LivebarnTools::Error, "OAuth authorization timed out after 120 seconds. Please try again."
      end

      request_line = conn.gets
      returned_state = request_line[/state=([^&\s]+)/, 1]
      unless returned_state == state
        conn.close
        server.close
        raise LivebarnTools::Error, "OAuth state mismatch — possible CSRF attack. Please try again."
      end

      code = request_line[/code=([^&\s]+)/, 1]

      conn.print "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
      conn.print "<html><body><h2>Authorization successful!</h2><p>You can close this tab.</p></body></html>"
      conn.close
      server.close

      unless code
        raise LivebarnTools::Error, "did not receive authorization code"
      end

      client.code = code
      client.fetch_access_token!
      save_token(client, token_path)

      client
    end

    def save_token(client, token_path = TOKEN_PATH)
      FileUtils.mkdir_p(File.dirname(token_path))
      data = {
        "refresh_token" => client.refresh_token,
        "access_token"  => client.access_token,
        "expires_at"    => client.expires_at&.iso8601
      }
      File.write(token_path, YAML.dump(data))
      File.chmod(0600, token_path)
    end

    def build_service(client)
      service = Google::Apis::YoutubeV3::YouTubeService.new
      service.authorization = client
      service
    end

    def upload_video(service, file_path, title, description)
      metadata = Google::Apis::YoutubeV3::Video.new(
        snippet: Google::Apis::YoutubeV3::VideoSnippet.new(
          title:       title,
          description: description
        ),
        status: Google::Apis::YoutubeV3::VideoStatus.new(
          privacy_status: "unlisted",
          self_declared_made_for_kids: true
        )
      )

      puts "Uploading #{File.basename(file_path)}..."

      video = service.insert_video(
        "snippet,status",
        metadata,
        upload_source: file_path,
        content_type:  "video/mp4"
      )

      puts "Upload complete!"
      video
    end

    def find_or_create_playlist(service, season_name)
      next_page = nil
      loop do
        response = service.list_playlists(
          "snippet,status",
          mine: true,
          max_results: 50,
          page_token: next_page
        )

        response.items&.each do |pl|
          return pl if pl.snippet.title == season_name
        end

        next_page = response.next_page_token
        break unless next_page
      end

      puts "Creating playlist: #{season_name}"
      playlist = Google::Apis::YoutubeV3::Playlist.new(
        snippet: Google::Apis::YoutubeV3::PlaylistSnippet.new(
          title: season_name
        ),
        status: Google::Apis::YoutubeV3::PlaylistStatus.new(
          privacy_status: "unlisted"
        )
      )

      service.insert_playlist("snippet,status", playlist)
    end

    def add_to_playlist(service, playlist_id, video_id)
      item = Google::Apis::YoutubeV3::PlaylistItem.new(
        snippet: Google::Apis::YoutubeV3::PlaylistItemSnippet.new(
          playlist_id: playlist_id,
          resource_id: Google::Apis::YoutubeV3::ResourceId.new(
            kind:     "youtube#video",
            video_id: video_id
          )
        )
      )

      service.insert_playlist_item("snippet", item)
    end
  end
end
