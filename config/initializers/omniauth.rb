# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :azure_activedirectory_v2,
    client_id: ENV['ENTRA_CLIENT_ID'],
    client_secret: ENV['ENTRA_CLIENT_SECRET'],
    tenant_id: ENV['ENTRA_TENANT_ID'],
    callback_path: '/auth/callback'
end
