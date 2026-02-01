# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval,
                       'https://cdn.jsdelivr.net',
                       'https://app.powerbi.com',
                       'https://app.powerbigov.us',
                       'https://login.microsoftonline.com',
                       'https://login.microsoftonline.us'
    policy.style_src   :self, :https, :unsafe_inline,
                       'https://cdn.jsdelivr.net'

    # Allow Power BI iframes
    policy.frame_src   :self,
                       'https://app.powerbi.com',
                       'https://app.powerbigov.us',
                       'https://login.microsoftonline.com',
                       'https://login.microsoftonline.us'

    # Allow connections to Power BI services
    policy.connect_src :self,
                       'https://app.powerbi.com',
                       'https://app.powerbigov.us',
                       'https://api.powerbi.com',
                       'https://api.powerbigov.us',
                       'https://login.microsoftonline.com',
                       'https://login.microsoftonline.us',
                       'https://wabi-us-gov-virginia-api.analysis.usgovcloudapi.net',
                       'wss://wabi-us-gov-virginia-api.analysis.usgovcloudapi.net'
  end

  # Generate session nonces for permitted importmap and inline scripts only
  # Note: Removing style-src from nonces to allow inline styles (for impersonation banner, modals, etc.)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy (for initial testing)
  # Uncomment to enforce after testing:
  # config.content_security_policy_report_only = false
end
