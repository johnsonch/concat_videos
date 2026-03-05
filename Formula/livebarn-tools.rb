class LivebarnTools < Formula
  desc "Process Livebarn hockey recordings into trimmed YouTube-ready videos"
  homepage "https://github.com/johnsonch/concat_videos"
  url "https://github.com/johnsonch/concat_videos.git",
      tag: "v1.0.0"
  license "MIT"
  head "https://github.com/johnsonch/concat_videos.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "ruby"

  def install
    system "bundle", "config", "set", "--local", "path", (libexec/"vendor").to_s
    system "bundle", "config", "set", "--local", "without", "test web"
    system "bundle", "install"

    libexec.install Dir["*", ".bundle"]

    %w[concat_videos trim_video upload_youtube process_game].each do |cmd|
      (bin/cmd).write_env_script(
        libexec/"bin"/cmd,
        BUNDLE_GEMFILE: libexec/"Gemfile"
      )
    end
  end

  test do
    assert_match "Usage", shell_output("#{bin}/process_game --help")
  end
end
