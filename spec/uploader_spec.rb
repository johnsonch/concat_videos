# frozen_string_literal: true

require "spec_helper"

RSpec.describe LivebarnTools::Uploader do
  let(:uploader) { described_class.new }

  describe "#parse_args" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        @video_path = File.join(dir, "game.mp4")
        File.write(@video_path, "fake video data")
        example.run
      end
    end

    it "parses valid arguments" do
      result = uploader.parse_args([@video_path, "--title", "My Game"])
      expect(result[:file]).to eq(@video_path)
      expect(result[:title]).to eq("My Game")
      expect(result[:description]).to eq("")
    end

    it "parses all options" do
      result = uploader.parse_args([
        @video_path,
        "--title", "My Game",
        "--season", "Spring 2026",
        "--description", "A great game"
      ])
      expect(result[:file]).to eq(@video_path)
      expect(result[:title]).to eq("My Game")
      expect(result[:season]).to eq("Spring 2026")
      expect(result[:description]).to eq("A great game")
    end

    it "raises LivebarnTools::Error when no file is given" do
      expect {
        uploader.parse_args(["--title", "My Game"])
      }.to raise_error(LivebarnTools::Error, /video file is required/)
    end

    it "raises LivebarnTools::Error when file does not exist" do
      expect {
        uploader.parse_args(["/nonexistent/video.mp4", "--title", "My Game"])
      }.to raise_error(LivebarnTools::Error, /file not found/)
    end

    it "raises LivebarnTools::Error when --title is missing" do
      expect {
        uploader.parse_args([@video_path])
      }.to raise_error(LivebarnTools::Error, /--title is required/)
    end

    it "exits 0 on --help" do
      expect {
        uploader.parse_args(["--help"])
      }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end
  end

  describe "#load_client_secret" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "loads credentials from 'installed' key" do
      path = File.join(@tmpdir, "secret.json")
      File.write(path, JSON.generate({
        "installed" => {
          "client_id" => "test-id",
          "client_secret" => "test-secret",
          "auth_uri" => "https://accounts.google.com/o/oauth2/auth",
          "token_uri" => "https://oauth2.googleapis.com/token"
        }
      }))

      cred = uploader.load_client_secret(path)
      expect(cred["client_id"]).to eq("test-id")
      expect(cred["client_secret"]).to eq("test-secret")
    end

    it "loads credentials from 'web' key" do
      path = File.join(@tmpdir, "secret.json")
      File.write(path, JSON.generate({
        "web" => {
          "client_id" => "web-id",
          "client_secret" => "web-secret"
        }
      }))

      cred = uploader.load_client_secret(path)
      expect(cred["client_id"]).to eq("web-id")
    end

    it "raises LivebarnTools::Error when file does not exist" do
      expect {
        uploader.load_client_secret("/nonexistent/secret.json")
      }.to raise_error(LivebarnTools::Error, /client_secret\.json not found/)
    end

    it "raises LivebarnTools::Error when JSON has no 'installed' or 'web' key" do
      path = File.join(@tmpdir, "secret.json")
      File.write(path, JSON.generate({ "other" => {} }))

      expect {
        uploader.load_client_secret(path)
      }.to raise_error(LivebarnTools::Error, /invalid client_secret\.json format/)
    end
  end

  describe "#save_token" do
    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "writes token YAML with restricted permissions" do
      token_path = File.join(@tmpdir, "tokens.yaml")
      client = double(
        refresh_token: "refresh-abc",
        access_token: "access-xyz",
        expires_at: Time.new(2026, 6, 1, 12, 0, 0)
      )

      uploader.save_token(client, token_path)

      expect(File.exist?(token_path)).to be true
      mode = File.stat(token_path).mode & 0777
      expect(mode).to eq(0600)

      data = YAML.safe_load(File.read(token_path))
      expect(data["refresh_token"]).to eq("refresh-abc")
      expect(data["access_token"]).to eq("access-xyz")
      expect(data["expires_at"]).to include("2026-06-01")
    end
  end

  describe "#build_service" do
    it "returns a YouTubeService with authorization set" do
      client = double("oauth_client")
      service = uploader.build_service(client)

      expect(service).to be_a(Google::Apis::YoutubeV3::YouTubeService)
      expect(service.authorization).to eq(client)
    end
  end

  describe "#upload_video" do
    it "uploads with correct metadata and returns the video" do
      service = instance_double(Google::Apis::YoutubeV3::YouTubeService)
      fake_video = double(id: "abc123")

      expect(service).to receive(:insert_video) do |parts, metadata, **kwargs|
        expect(parts).to eq("snippet,status")
        expect(metadata.snippet.title).to eq("Game Title")
        expect(metadata.snippet.description).to eq("A game")
        expect(metadata.status.privacy_status).to eq("unlisted")
        expect(kwargs[:upload_source]).to eq("/tmp/game.mp4")
        expect(kwargs[:content_type]).to eq("video/mp4")
        fake_video
      end

      result = uploader.upload_video(service, "/tmp/game.mp4", "Game Title", "A game")
      expect(result.id).to eq("abc123")
    end
  end

  describe "#find_or_create_playlist" do
    let(:service) { instance_double(Google::Apis::YoutubeV3::YouTubeService) }

    it "returns an existing playlist when found" do
      matching_playlist = double(
        snippet: double(title: "Spring 2026"),
        id: "PL_existing"
      )
      response = double(
        items: [matching_playlist],
        next_page_token: nil
      )

      allow(service).to receive(:list_playlists).and_return(response)

      result = uploader.find_or_create_playlist(service, "Spring 2026")
      expect(result.id).to eq("PL_existing")
    end

    it "creates a new playlist when not found" do
      empty_response = double(items: [], next_page_token: nil)
      new_playlist = double(id: "PL_new")

      allow(service).to receive(:list_playlists).and_return(empty_response)
      expect(service).to receive(:insert_playlist) do |parts, playlist|
        expect(parts).to eq("snippet,status")
        expect(playlist.snippet.title).to eq("Fall 2025")
        expect(playlist.status.privacy_status).to eq("unlisted")
        new_playlist
      end

      result = uploader.find_or_create_playlist(service, "Fall 2025")
      expect(result.id).to eq("PL_new")
    end

    it "paginates through playlists to find a match" do
      page1_response = double(
        items: [double(snippet: double(title: "Other"))],
        next_page_token: "page2"
      )
      matching_playlist = double(
        snippet: double(title: "Spring 2026"),
        id: "PL_page2"
      )
      page2_response = double(
        items: [matching_playlist],
        next_page_token: nil
      )

      call_count = 0
      allow(service).to receive(:list_playlists) do |_parts, **kwargs|
        call_count += 1
        call_count == 1 ? page1_response : page2_response
      end

      result = uploader.find_or_create_playlist(service, "Spring 2026")
      expect(result.id).to eq("PL_page2")
      expect(call_count).to eq(2)
    end
  end

  describe "#add_to_playlist" do
    it "inserts a playlist item with correct video and playlist IDs" do
      service = instance_double(Google::Apis::YoutubeV3::YouTubeService)

      expect(service).to receive(:insert_playlist_item) do |parts, item|
        expect(parts).to eq("snippet")
        expect(item.snippet.playlist_id).to eq("PL_abc")
        expect(item.snippet.resource_id.video_id).to eq("vid_123")
        expect(item.snippet.resource_id.kind).to eq("youtube#video")
      end

      uploader.add_to_playlist(service, "PL_abc", "vid_123")
    end
  end
end
