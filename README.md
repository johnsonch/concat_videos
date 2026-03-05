# Livebarn Game Video Toolkit

[![Tests](https://github.com/johnsonch/concat_videos/actions/workflows/ci.yml/badge.svg)](https://github.com/johnsonch/concat_videos/actions/workflows/ci.yml)

Turn raw Livebarn arena recordings into clean, trimmed game videos and publish them to YouTube - no video editing software required.

Livebarn captures hockey games as a series of 30-minute segments from a fixed rink camera. This toolkit merges those segments into a single file, trims the dead time before and after the game, strips arena audio if you want, and uploads the result as an unlisted YouTube video organized into per-season playlists. The whole process takes one command or a few clicks.

**Self-hosted web UI** - Run `docker-compose up` and open a browser. A step-by-step wizard walks you through uploading segments, previewing video with a built-in player, clicking to set trim points, and downloading or uploading to YouTube. Everything runs locally on your machine.

**CLI for scripting and AI agents** - Four composable commands (`concat_videos`, `trim_video`, `upload_youtube`, `process_game`) that work from the terminal, in shell scripts, or driven by AI coding assistants like Claude Code. Install natively on macOS/Linux or run via Docker.

## Quick Install

### Mac (Homebrew)

```sh
brew tap johnsonch/concat-videos https://github.com/johnsonch/concat_videos
brew install livebarn-tools
```

This installs the CLI tools and FFmpeg. Run `brew upgrade livebarn-tools` to update.

### Mac / Linux (shell script)

Alternative if you don't use Homebrew, or on Linux:

```sh
# Install dependencies first
brew install ffmpeg ruby git        # macOS
# sudo apt install ffmpeg ruby-full git  # Ubuntu / Debian

# Install livebarn tools
curl -sSL https://raw.githubusercontent.com/johnsonch/concat_videos/main/install.sh | bash
```

This clones the repo to `~/.livebarn-tools`, installs Ruby gems, and symlinks four commands into `/usr/local/bin`. Run it again to update.

### Windows

Installs the Web UI via Docker. Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [Git](https://git-scm.com/download/win).

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/johnsonch/concat_videos/main/install.ps1 | iex
```

This clones the repo, builds the Docker image, and tells you how to start the Web UI. To launch it afterward:

```powershell
cd "$env:USERPROFILE\.livebarn-tools"
docker compose up
```

Then open http://localhost:4567 in your browser.

## All Installation Options

| Method                              | Best for                                                  | Setup                                         |
|-------------------------------------|-----------------------------------------------------------|-----------------------------------------------|
| [**Web UI**](#web-ui-docker)        | Interactive use - preview video, click to set trim points | `docker-compose up --build`                   |
| [**CLI (Homebrew)**](#mac-homebrew) | macOS users                                               | `brew tap ... && brew install livebarn-tools` |
| [**CLI (native)**](#cli-native)     | Scripting, AI agents, automation on macOS/Linux           | `curl` install or `make install`              |
| [**CLI (Docker)**](#cli-docker)     | CLI without installing Ruby/FFmpeg locally                | `docker build -t livebarn-tools .`            |

---

## Workflow

```
Download segments from Livebarn
        │
        ▼
  concat_videos    ← merge arena segments into one file
        │
        ▼
   trim_video      ← trim pre-game / post-game footage
        │
        ▼
 upload_youtube    ← upload as unlisted, add to season playlist
```

Or use `process_game` to run all three steps in one command.

## YouTube / Google Cloud Setup

To upload videos to YouTube, you need Google OAuth credentials. This is a one-time setup.

### 1. Create Google OAuth credentials

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) and create a project (or select an existing one)
2. Enable the **YouTube Data API v3** (APIs & Services → Library → search "YouTube Data API v3")
3. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**
4. Application type: **Desktop app**
5. Download the JSON file

### 2. Place the credentials file

| Platform        | Path                                                      |
|-----------------|-----------------------------------------------------------|
| macOS / Linux   | `~/.config/livebarn_tools/client_secret.json`             |
| Windows         | `%USERPROFILE%\.config\livebarn_tools\client_secret.json` |
| Docker (any OS) | Mount the directory into the container (see below)        |

**macOS / Linux:**

```sh
mkdir -p ~/.config/livebarn_tools
cp ~/Downloads/client_secret_*.json ~/.config/livebarn_tools/client_secret.json
```

**Windows (PowerShell):**

```powershell
mkdir "$env:USERPROFILE\.config\livebarn_tools" -Force
copy "$env:USERPROFILE\Downloads\client_secret_*.json" "$env:USERPROFILE\.config\livebarn_tools\client_secret.json"
```

### 3. Authorize

On first upload, a browser window opens for Google authorization. You approve access once and a refresh token is saved so you don't need to authorize again.

- **CLI (native):** Just run `upload_youtube` or `process_game` - the browser opens automatically.
- **Docker / Web UI:** The OAuth loopback flow requires a browser on the host. Authorize on macOS/Linux first using the native CLI, then mount the tokens into Docker. On Windows, use the Web UI - it will display the authorization URL for you to open manually.

**Windows with Docker (Web UI):**

```powershell
docker-compose up --build
```

The `docker-compose.yml` mounts `~/.config/livebarn_tools` from your home directory. On Windows, Docker Desktop maps `$HOME` to `%USERPROFILE%`. If you haven't authorized yet, the Web UI will show the Google authorization URL - open it in your browser, approve access, and the token will be saved for future use.

**Windows with Docker (CLI):**

```powershell
docker run --rm -it -v "${PWD}:/workspace" -v "${env:USERPROFILE}\.config\livebarn_tools:/root/.config/livebarn_tools" livebarn-tools process_game --help
```

## Livebarn Plan Requirement

This workflow requires the [Livebarn Premium plan](https://www.livebarn.com/pricing), which allows downloading 30-minute video clips. The Standard plan only supports 30-second clip downloads, which is not practical for full game processing.

## Livebarn File Naming

Livebarn downloads video in 30-minute segments named with the arena and timestamp:

```
Kettle_Moraine_Ice_Center_Rink_1_2026-02-14T135956.mp4
Kettle_Moraine_Ice_Center_Rink_1_2026-02-14T142956.mp4
Kettle_Moraine_Ice_Center_Rink_1_2026-02-14T145956.mp4
Kettle_Moraine_Ice_Center_Rink_1_2026-02-14T152956.mp4
```

The general pattern is `{Arena_Name}_Rink_{N}_{YYYY}-{MM}-{DD}T{HHMMSS}.mp4`. Other examples:

```
Viroqua_Community_Arena_Rink_1_2026-02-21T092956.mp4
Sauk_Prairie_Ice_Arena_Rink_1_2026-02-28T094530.mp4
Lake_Delton_Ice_Arena_Rink_1_2026-02-28T145955.mp4
Onalaska_Omni_Center_Arena_2_2026-01-17T083333.mp4
```

The `arena_name` argument to `concat_videos` and `process_game` is the portion before the date - e.g., `Kettle_Moraine_Ice_Center_Rink_1`. The tool globs for `{arena_name}_*.mp4` in the current directory, so if you have multiple games at the same arena, put each game's segments in a separate folder. The Web UI detects the arena automatically from the uploaded filenames.

---

## Web UI

A browser-based wizard for interactive game processing. Upload segments, preview video with a built-in player, click to set trim points, and download or upload the result.

If you installed via Homebrew or the install script, just run:

```sh
livebarn-server
```

This starts the web UI and opens your browser to http://localhost:4567. If the web gems aren't installed locally, it falls back to Docker automatically.

You can also run it directly with Docker:

```sh
docker-compose up --build
```

Follow the steps:

1. **Upload** - Select MP4 segments and enter the game title (e.g., "Tigers vs Hawks")
2. **Concatenate** - Segments are merged automatically with progress feedback
3. **Trim** - Use the video player to find trim points, click "Use current position" to set them
4. **Output** - Download the MP4 or upload directly to YouTube

The arena name is detected automatically from the Livebarn filenames. YouTube upload requires OAuth tokens - authenticate on the host first (`upload_youtube` or `process_game`), then the mounted `~/.config/livebarn_tools/tokens.yaml` is used by the container.

---

## CLI (Native)

Install directly on macOS or Linux for the fastest experience. The CLI commands are ideal for scripting, automation, and AI agents.

### Requirements

- **FFmpeg** / **ffprobe** - video concatenation and trimming
- **Ruby** + **Bundler** - all tools are Ruby scripts
- **macOS** - tested and fully supported
- **Linux** - should work (uses `xdg-open` fallback for OAuth)

Install dependencies before running the install script:

```sh
# macOS
brew install ffmpeg ruby git

# Ubuntu / Debian
sudo apt install ffmpeg ruby-full git
```

### Manual Installation

If you prefer not to use the quick install script:

```sh
git clone https://github.com/johnsonch/concat_videos.git
cd concat_videos
make deps      # check system tools + install Ruby gems
sudo make install
```

This symlinks four commands into `/usr/local/bin`:

| Command           | Description                             |
|-------------------|-----------------------------------------|
| `livebarn-server` | Start the web UI                        |
| `concat_videos`   | Merge Livebarn segments into one MP4    |
| `trim_video`      | Trim front/end of a video               |
| `upload_youtube`  | Upload to YouTube + playlist management |
| `process_game`    | All-in-one CLI orchestrator             |

Updates via `git pull` take effect immediately since the commands are symlinks.

To uninstall:

```sh
sudo make uninstall
```

### Usage

#### All-in-one: `process_game`

```sh
process_game <arena_name> <team_name> <front_trim> <end_trim> --season SEASON [--title TITLE]
```

This concatenates segments, trims the video, uploads to YouTube, and adds it to a season playlist.

```sh
# Trim 12 minutes off the front and 5 off the end, upload to Spring 2026 playlist
process_game main-court tigers 00:12:00 00:05:00 --season "Spring 2026"

# Same, with a custom title
process_game main-court tigers 00:12:00 00:05:00 --season "Spring 2026" --title "vs Hawks - Mar 1"

# Process locally without uploading
process_game main-court tigers 00:12:00 00:05:00 --season x --skip-upload
```

Options:
- `--season SEASON` - playlist name (required unless `--skip-upload`)
- `--title TITLE` - video title (auto-generated from date + team if omitted)
- `--no-audio` - remove audio track from the trimmed video
- `--no-cleanup` - keep the intermediate concatenated file
- `--skip-upload` - skip the YouTube upload step

#### Individual tools

##### `concat_videos`

```sh
concat_videos <arena_name> <team_name>
```

Finds all `{arena_name}_*.mp4` files in the current directory, sorts them, and concatenates into `{date}_{team_name}.mp4`.

```sh
concat_videos main-court tigers
# Output: 2026-03-01_tigers.mp4
```

##### `trim_video`

```sh
trim_video <input_file> <front_trim> <end_trim>
```

Trims the first `<front_trim>` and last `<end_trim>` from a video. Times in `HH:MM:SS`, `MM:SS`, or seconds.

```sh
trim_video 2026-03-01_tigers.mp4 00:12:00 00:05:00
# Output: 2026-03-01_tigers_trimmed.mp4

# Same, but strip the audio track
trim_video --no-audio 2026-03-01_tigers.mp4 00:12:00 00:05:00
```

##### `upload_youtube`

```sh
upload_youtube <video_file> --title TITLE [--season SEASON] [--description DESC]
```

Uploads a video as unlisted. If `--season` is provided, finds or creates a matching unlisted playlist and adds the video.

```sh
upload_youtube game_trimmed.mp4 --title "vs Tigers - Mar 1" --season "Spring 2026"
```

---

## CLI (Docker)

Run the CLI tools in Docker without installing Ruby or FFmpeg on the host.

Build the image once:

```sh
docker build -t livebarn-tools .
```

Run any command by mounting your video directory and config:

```sh
# Concatenate segments
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.config/livebarn_tools:/root/.config/livebarn_tools" \
  livebarn-tools concat_videos main-court tigers

# Trim a video
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.config/livebarn_tools:/root/.config/livebarn_tools" \
  livebarn-tools trim_video 2026-03-01_tigers.mp4 00:12:00 00:05:00

# Upload to YouTube
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.config/livebarn_tools:/root/.config/livebarn_tools" \
  livebarn-tools upload_youtube game_trimmed.mp4 --title "vs Tigers" --season "Spring 2026"

# All-in-one
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.config/livebarn_tools:/root/.config/livebarn_tools" \
  livebarn-tools process_game main-court tigers 00:12:00 00:05:00 --season "Spring 2026"
```

**Note:** YouTube authentication requires a browser, so run `upload_youtube` on the host first to generate `~/.config/livebarn_tools/tokens.yaml`, then mount it into the container for subsequent uploads.

## License

MIT - see [LICENSE](LICENSE) for details.
