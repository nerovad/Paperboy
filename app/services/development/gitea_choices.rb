# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'

module Development
  # Reads label, milestone, and project names for the issue forms.
  # A failed lookup leaves those fields as plain text.
  class GiteaChoices
    def self.fetch
      stdout, _stderr, status = Timeout.timeout(20) do
        Open3.capture3(
          { 'GITEA_CONNECT_TIMEOUT' => '3', 'GITEA_MAX_TIME' => '5' },
          Rails.root.join('bin/gitea-lookups').to_s
        )
      end
      return unless status.success?

      parsed = JSON.parse(stdout)
      parsed if parsed.is_a?(Hash)
    rescue StandardError
      nil
    end
  end
end
