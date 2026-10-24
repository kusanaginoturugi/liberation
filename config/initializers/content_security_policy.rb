# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    # Views use style= attributes, so inline styles stay allowed.
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self, :data
    policy.font_src        :self, :data
    policy.connect_src     :self
    policy.object_src      :none
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  # Inline <script> tags must carry nonce="<%= content_security_policy_nonce %>".
  # Keep style-src out of the nonce directives: a nonce there disables 'unsafe-inline'.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
