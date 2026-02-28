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
                       'https://cdn.jsdelivr.net'
    policy.style_src   :self, :https, :unsafe_inline,
                       'https://cdn.jsdelivr.net'

    # Allow Metabase iframes
    metabase_url = ENV.fetch('METABASE_SITE_URL', 'http://localhost:3000')
    policy.frame_src   :self, metabase_url

    policy.connect_src :self
  end

  # Generate session nonces for permitted importmap and inline scripts only
  # Note: Removing style-src from nonces to allow inline styles (for impersonation banner, modals, etc.)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy (for initial testing)
  # Uncomment to enforce after testing:
  # config.content_security_policy_report_only = false
end
