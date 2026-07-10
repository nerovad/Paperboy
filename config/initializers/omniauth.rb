# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :entra_id,
           client_id: ENV.fetch('ENTRA_CLIENT_ID', nil),
           client_secret: ENV.fetch('ENTRA_CLIENT_SECRET', nil),
           tenant_id: ENV.fetch('ENTRA_TENANT_ID', nil),
           callback_path: '/auth/callback'
end
