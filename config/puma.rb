# frozen_string_literal: true

workers 0
threads 1, 4
port ENV.fetch("PORT", 4567)
environment ENV.fetch("RACK_ENV", "production")
