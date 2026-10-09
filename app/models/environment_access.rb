# frozen_string_literal: true

# app/models/environment_access.rb
#
# Who may use the Development and Stage servers.
#
# Both exist for testing, and staff kept working in Stage by accident — an old
# bookmark, a link in a Stage notification — so neither opens to somebody just
# because they can sign in. Each is a grant of its own, given in ACL > Test
# Environments to a group or an org level like any other permission.
# Production is not listed here and is never gated.
#
# ApplicationController#require_environment_access is the gate; a refused
# visitor lands on EnvironmentAccessController, which sends them on to
# Production or to the support channel.
class EnvironmentAccess
  # Group_Permissions / org_permissions rows carrying environment access, keyed
  # by the environment — "dev", "stage". The rows travel to every database in
  # db/acl.yml; one naming an environment other than the one it sits in simply
  # grants nothing there.
  PERMISSION_TYPE = 'environment'

  ENVIRONMENTS = [
    { key: 'dev',   label: 'Development', rails_env: 'development' },
    { key: 'stage', label: 'Stage',       rails_env: 'staging' }
  ].freeze

  # A workstation runs the development environment too, against its own
  # database, and must not need a grant to boot.
  LOCAL_HOSTS = ['localhost', '127.0.0.1', '::1'].freeze

  SUPPORT_CHANNEL_NAME = 'Paperboy-Support'
  SUPPORT_CHANNEL_URL = 'https://teams.microsoft.com/l/channel/' \
                        '19%3A6FKLb1oznhKjazF75qkfWTVfmH78CJgX-6oFWJ33otA1%40thread.tacv2/Paperboy-Support' \
                        '?groupId=23f37c20-e81c-4781-9412-7087c972f670' \
                        '&tenantId=bce0ec04-d1f1-4f5a-a050-a4b5e9181683'

  class << self
    # The grant key this request's environment asks for, or nil when it asks
    # for none: Production, the test suite, and a developer's localhost.
    def key_for(host:, rails_env: Rails.env)
      return if LOCAL_HOSTS.include?(host.to_s)

      ENVIRONMENTS.find { |environment| environment[:rails_env] == rails_env.to_s }&.fetch(:key)
    end

    def label_for(key)
      ENVIRONMENTS.find { |environment| environment[:key] == key.to_s }&.fetch(:label)
    end

    def permission_keys
      ENVIRONMENTS.pluck(:key)
    end

    # Where a refused visitor is sent. The same address from every server, so
    # it is read from the list the Production sidebar already keeps.
    def production_url
      Production::Links::ALL.find { |link| link[:group] == :paperboy && link[:label] == 'Production' }.fetch(:url)
    end
  end
end
