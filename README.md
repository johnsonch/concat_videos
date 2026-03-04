# Livebarn Game Video Toolkit

Process Livebarn hockey game recordings: download segments, concatenate them, trim to game length, and upload to YouTube as unlisted videos organized into per-season playlists.

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

## Requirements

- **FFmpeg** / **ffprobe** — video concatenation and trimming
- **Ruby** + **Bundler** — all tools are Ruby scripts

Check and install dependencies:

```sh
make deps
```

## Installation

```sh
git clone https://github.com/yourusername/concat_videos.git
cd concat_videos
make deps      # check system tools + install Ruby gems
sudo make install
```

This symlinks four commands into `/usr/local/bin`:

| Command          | Description                             |
|------------------|-----------------------------------------|
| `concat_videos`  | Merge Livebarn segments into one MP4    |
| `trim_video`     | Trim front/end of a video               |
| `upload_youtube` | Upload to YouTube + playlist management |
| `process_game`   | All-in-one orchestrator                 |

Updates via `git pull` take effect immediately since the commands are symlinks.

To uninstall:

```sh
sudo make uninstall
```

## YouTube / Google Cloud Setup

Before uploading, you need Google OAuth credentials:

```sh
make setup
```

This prints step-by-step instructions. In short:

1. Create a project at [console.cloud.google.com](https://console.cloud.google.com/)
2. Enable the **YouTube Data API v3**
3. Create an **OAuth 2.0 client ID** (Desktop app type)
4. Download the JSON and copy it to `~/.config/livebarn_tools/client_secret.json`

On first upload, a browser window opens for Google authorization. The refresh token is saved at `~/.config/livebarn_tools/tokens.yaml` so you only authorize once.

## Usage

### All-in-one: `process_game`

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
- `--season SEASON` — playlist name (required unless `--skip-upload`)
- `--title TITLE` — video title (auto-generated from date + team if omitted)
- `--no-cleanup` — keep the intermediate concatenated file
- `--skip-upload` — skip the YouTube upload step

### Individual tools

#### `concat_videos`

```sh
concat_videos <arena_name> <team_name>
```

Finds all `{arena_name}_*.mp4` files in the current directory, sorts them, and concatenates into `{date}_{team_name}.mp4`.

```sh
concat_videos main-court tigers
# Output: 2026-03-01_tigers.mp4
```

#### `trim_video`

```sh
trim_video <input_file> <front_trim> <end_trim>
```

Trims the first `<front_trim>` and last `<end_trim>` from a video. Times in `HH:MM:SS`, `MM:SS`, or seconds.

```sh
trim_video 2026-03-01_tigers.mp4 00:12:00 00:05:00
# Output: 2026-03-01_tigers_trimmed.mp4
```

#### `upload_youtube`

```sh
upload_youtube <video_file> --title TITLE [--season SEASON] [--description DESC]
```

Uploads a video as unlisted. If `--season` is provided, finds or creates a matching unlisted playlist and adds the video.

```sh
upload_youtube game_trimmed.mp4 --title "vs Tigers - Mar 1" --season "Spring 2026"
```

## License

MIT — see [LICENSE](LICENSE) for details.
