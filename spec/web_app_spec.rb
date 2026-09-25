# frozen_string_literal: true

require "spec_helper"
require "rack/mock"
require_relative "../web/app"

RSpec.describe LivebarnTools::WebApp do
  describe "GET /download/:id" do
    it "downloads a trimmed file without the _trimmed suffix" do
      job = described_class::JOBS.create(arena: "rink", team: "tigers")
      file = File.join(job.work_dir, "2026-03-01_tigers_trimmed.mp4")
      File.write(file, "video")
      described_class::JOBS.update(job.id, trimmed_file: file)

      response = Rack::MockRequest.new(described_class).get("/download/#{job.id}")

      expect(response.status).to eq(200)
      expect(response["content-disposition"]).to include('filename="2026-03-01_tigers.mp4"')
    end
  end
end
