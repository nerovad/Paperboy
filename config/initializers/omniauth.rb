# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :entra_id,
    client_id: ENV['ENTRA_CLIENT_ID'],
    client_secret: ENV['ENTRA_CLIENT_SECRET'],
    tenant_id: ENV['ENTRA_TENANT_ID'],
    callback_path: '/auth/callback'
end
