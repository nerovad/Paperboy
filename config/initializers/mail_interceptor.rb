# config/initializers/mail_interceptor.rb
if Rails.env.development?
  require Rails.root.join('lib', 'development_mail_interceptor')
  ActionMailer::Base.register_interceptor(DevelopmentMailInterceptor)

  Rails.logger.info "✅ Development mail interceptor enabled - all emails will be redirected"
end
