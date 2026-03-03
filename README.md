# Concat Videos

Concatenate multiple MP4 video files from a sports arena into a single video, named by date and team.

## Features

- Finds all MP4 files matching an arena name pattern in the current directory
- Extracts the date from filenames automatically
- Concatenates videos losslessly using FFmpeg stream copy
- Outputs a single file named `{date}_{team_name}.mp4`

## Requirements

- **FFmpeg** — video concatenation

Check dependencies with:

```sh
make deps
```

## Installation

```sh
git clone https://github.com/yourusername/concat_videos.git
cd concat_videos
make deps      # check for required tools
sudo make install
```

This symlinks `concat_videos` into `/usr/local/bin` pointing back to the repo, so the project just needs to stay where you cloned it. Updates via `git pull` take effect immediately.

To uninstall:

```sh
sudo make uninstall
```

You can also run the script directly from the repo without installing:

```sh
./concat_videos.sh <arena_name> <team_name>
```

## Usage

```sh
concat_videos <arena_name> <team_name>
```

**Arguments:**

- `arena_name` — Name of the arena; matches files named `{arena_name}_*.mp4` in the current directory
- `team_name` — Team name used in the output filename

**Example:**

```sh
# Concatenate all videos from "main-court" arena for team "tigers"
# Given files: main-court_2026-03-01T10-00.mp4, main-court_2026-03-01T11-00.mp4
concat_videos main-court tigers
# Output: 2026-03-01_tigers.mp4
```

## How It Works

1. Finds all `{arena_name}_*.mp4` files in the current directory
2. Generates a temporary file list for FFmpeg
3. Extracts the date stamp from the first matching filename
4. Concatenates all matching videos losslessly with `ffmpeg -c copy`
5. Cleans up the temporary file list
6. Outputs the result as `{date}_{team_name}.mp4`

## License

MIT — see [LICENSE](LICENSE) for details.
