# frozen_string_literal: true

# Encryption keys, per host, from .env rather than from Rails credentials.
#
# Assigning them to config.active_record.encryption is not enough on its own:
# Active Record reads that config through an +on_load(:active_record_encryption)+
# hook which, depending on what has already touched Active Record, may have run
# before this file did — leaving every encrypted attribute raising "Missing
# Active Record encryption credential" although the keys were right there in
# the environment. Configuring the module directly as well is what makes the
# keys take effect whichever order the two happen in.
%w[primary_key deterministic_key key_derivation_salt].each do |setting|
  value = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_#{setting.upcase}", nil).presence
  Rails.application.config.active_record.encryption.public_send(:"#{setting}=", value)
end

keys = Rails.application.config.active_record.encryption

if keys.primary_key.present?
  ActiveRecord::Encryption.configure(
    primary_key: keys.primary_key,
    deterministic_key: keys.deterministic_key,
    key_derivation_salt: keys.key_derivation_salt,
    # A column that held plain text before it was declared encrypted still
    # reads. Nothing writes plain text once the keys are set, so this only
    # covers rows written before they were.
    support_unencrypted_data: true
  )
end
