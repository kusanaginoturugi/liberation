require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "pages send a content security policy whose nonce matches inline scripts" do
    get new_session_path

    policy = response.headers["Content-Security-Policy"]
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    nonce = policy[/script-src 'self' 'nonce-([^']+)'/, 1]
    assert nonce.present?
    assert_includes response.body, %(<script nonce="#{nonce}">)
    assert_not_includes response.body, "<script>"
  end

  test "views do not use inline event handlers blocked by the content security policy" do
    handler = /(?<![\w-])on[a-z]+(?::\s*["']|=["'])/
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select { |path| File.read(path).match?(handler) }

    assert_empty offenders
  end

  test "pages restrict unused browser features" do
    get new_session_path

    assert_includes response.headers["Permissions-Policy"], "camera=()"
  end
end
