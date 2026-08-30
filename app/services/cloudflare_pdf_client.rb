require "net/http"
require "json"

class CloudflarePdfClient
  class Error < StandardError; end

  def self.render(html:)
    worker_url = ENV.fetch("CLOUDFLARE_PDF_WORKER_URL")
    token = ENV.fetch("CLOUDFLARE_PDF_TOKEN")
    uri = URI(worker_url)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = { html: }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: 45) do |http|
      http.request(request)
    end

    return response.body if response.is_a?(Net::HTTPSuccess) && response.content_type == "application/pdf"

    raise Error, "CloudflareでPDFを作成できませんでした"
  rescue KeyError
    raise Error, "Cloudflare PDFの設定がありません"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError
    raise Error, "Cloudflareへの接続がタイムアウトしました"
  end
end
