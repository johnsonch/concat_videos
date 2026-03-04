# frozen_string_literal: true

require "securerandom"
require "tmpdir"

module LivebarnTools
  Job = Struct.new(:id, :work_dir, :arena, :team, :concat_file, :trimmed_file,
                   :messages, :status, :error, keyword_init: true)

  class JobStore
    def initialize
      @mutex = Mutex.new
      @jobs = {}
    end

    def create(arena:, team:)
      id = SecureRandom.uuid
      work_dir = Dir.mktmpdir("livebarn_#{id}")
      job = Job.new(
        id: id,
        work_dir: work_dir,
        arena: arena,
        team: team,
        messages: [],
        status: :pending
      )
      @mutex.synchronize { @jobs[id] = job }
      job
    end

    def get(id)
      @mutex.synchronize { @jobs[id] }
    end

    def push_message(id, message)
      @mutex.synchronize do
        job = @jobs[id]
        job.messages << message if job
      end
    end

    def messages_since(id, index)
      @mutex.synchronize do
        job = @jobs[id]
        return [] unless job
        job.messages[index..] || []
      end
    end

    def update(id, **attrs)
      @mutex.synchronize do
        job = @jobs[id]
        return unless job
        attrs.each { |k, v| job[k] = v }
        job
      end
    end
  end
end
