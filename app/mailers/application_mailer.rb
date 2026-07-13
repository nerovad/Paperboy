# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'gsa-forms@ventura.org'
  layout 'mailer'
end
