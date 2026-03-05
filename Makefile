BINDIR ?= /usr/local/bin
CURDIR_ABS := $(shell pwd)

BINS = concat_videos trim_video upload_youtube process_game livebarn-server

.PHONY: install uninstall deps setup test

install:
	@echo "Installing livebarn game tools..."
	@mkdir -p $(BINDIR)
	@ln -sf $(CURDIR_ABS)/bin/concat_videos   $(BINDIR)/concat_videos
	@ln -sf $(CURDIR_ABS)/bin/trim_video      $(BINDIR)/trim_video
	@ln -sf $(CURDIR_ABS)/bin/upload_youtube  $(BINDIR)/upload_youtube
	@ln -sf $(CURDIR_ABS)/bin/process_game    $(BINDIR)/process_game
	@ln -sf $(CURDIR_ABS)/bin/livebarn-server $(BINDIR)/livebarn-server
	@echo ""
	@echo "Symlinked to $(BINDIR):"
	@echo "  livebarn-server -> $(CURDIR_ABS)/bin/livebarn-server"
	@echo "  concat_videos   -> $(CURDIR_ABS)/bin/concat_videos"
	@echo "  trim_video      -> $(CURDIR_ABS)/bin/trim_video"
	@echo "  upload_youtube  -> $(CURDIR_ABS)/bin/upload_youtube"
	@echo "  process_game    -> $(CURDIR_ABS)/bin/process_game"
	@echo ""
	@echo "Run 'livebarn-server' to start the web UI."
	@echo "Run 'process_game --help' for CLI usage."

uninstall:
	@echo "Uninstalling livebarn game tools..."
	@rm -f $(addprefix $(BINDIR)/,$(BINS))
	@echo "Done."

deps:
	@echo "Checking dependencies..."
	@echo ""
	@missing=0; \
	for cmd in ffmpeg ffprobe ruby bundle docker; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "  [ok] $$cmd"; \
		else \
			echo "  [MISSING] $$cmd"; \
			missing=1; \
		fi; \
	done; \
	echo ""; \
	if [ $$missing -eq 1 ]; then \
		echo "Install missing dependencies:"; \
		echo "  macOS:  brew install ffmpeg ruby docker"; \
		echo "  Ubuntu: sudo apt install ffmpeg ruby-full docker.io"; \
		echo ""; \
		echo "Then install bundler: gem install bundler"; \
		exit 1; \
	else \
		echo "All system dependencies are installed."; \
		echo ""; \
		echo "Installing Ruby gems..."; \
		bundle install; \
	fi

test:
	bundle exec rspec

setup:
	@echo "=== YouTube Upload Setup ==="
	@echo ""
	@echo "To upload videos, you need a Google Cloud project with the"
	@echo "YouTube Data API v3 enabled and an OAuth 2.0 client ID."
	@echo ""
	@echo "Steps:"
	@echo "  1. Go to https://console.cloud.google.com/"
	@echo "  2. Create a project (or select an existing one)"
	@echo "  3. Enable the 'YouTube Data API v3'"
	@echo "  4. Go to Credentials -> Create Credentials -> OAuth client ID"
	@echo "  5. Application type: Desktop app"
	@echo "  6. Download the JSON file"
	@echo ""
	@mkdir -p ~/.config/livebarn_tools
	@echo "Now copy your downloaded client secret JSON:"
	@echo ""
	@echo "  cp ~/Downloads/client_secret_*.json ~/.config/livebarn_tools/client_secret.json"
	@echo ""
	@echo "Then run 'upload_youtube' or 'process_game' - it will open your"
	@echo "browser for authorization on first use."
