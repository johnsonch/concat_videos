BINDIR ?= /usr/local/bin
SCRIPT  = $(CURDIR)/concat_videos.sh

.PHONY: install uninstall deps

install:
	@echo "Installing concat_videos..."
	@mkdir -p $(BINDIR)
	@ln -sf $(SCRIPT) $(BINDIR)/concat_videos
	@echo ""
	@echo "Symlinked:"
	@echo "  $(BINDIR)/concat_videos -> $(SCRIPT)"
	@echo ""
	@echo "Run 'concat_videos --help' to get started."
	@echo ""
	@echo "NOTE: You may need to open a new terminal or run:"
	@echo "  source ~/.bashrc   # (or ~/.zshrc)"
	@echo "for the 'concat_videos' command to be found in your PATH."

uninstall:
	@echo "Uninstalling concat_videos..."
	rm -f $(BINDIR)/concat_videos
	@echo "Done."

deps:
	@echo "Checking dependencies..."
	@echo ""
	@missing=0; \
	if command -v ffmpeg >/dev/null 2>&1; then \
		echo "  [ok] ffmpeg"; \
	else \
		echo "  [MISSING] ffmpeg"; \
		missing=1; \
	fi; \
	echo ""; \
	if [ $$missing -eq 1 ]; then \
		echo "Install missing dependencies:"; \
		echo "  macOS:  brew install ffmpeg"; \
		echo "  Ubuntu: sudo apt install ffmpeg"; \
		exit 1; \
	else \
		echo "All dependencies are installed."; \
	fi
