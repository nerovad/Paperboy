# lib/development_mail_interceptor.rb
class DevelopmentMailInterceptor
  def self.delivering_email(message)
    # Store original recipients for debugging
    original_to = message.to
    original_cc = message.cc
    original_bcc = message.bcc

    # Replace all recipients with your test email
    test_email = ENV['DEV_EMAIL'] || 'your-test-email@ventura.org'

    message.to = test_email
    message.cc = nil
    message.bcc = nil

    # Add original recipients to subject for clarity
    original_recipients = [original_to, original_cc, original_bcc].flatten.compact.join(', ')
    message.subject = "[DEV - would send to: #{original_recipients}] #{message.subject}"

    Rails.logger.info "📧 Email intercepted - Original: #{original_recipients} → Redirected to: #{test_email}"
  end
end
