FROM ruby:3.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg build-essential && rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app
RUN bundle install

ENV PATH="/app/bin:${PATH}"
VOLUME ["/root/.config/livebarn_tools", "/workspace"]
WORKDIR /workspace
