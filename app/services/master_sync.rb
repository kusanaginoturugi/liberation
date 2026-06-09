# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class MasterSync
  class FetchError < StandardError; end

  Result = Struct.new(:count, :master_updated_at, keyword_init: true)

  DEFAULT_REGION_ID = 1

  def self.run
    new.run
  end

  def initialize(base_url: Rails.application.config.masters_url)
    @base_url = base_url.to_s.sub(%r{/+\z}, "")
  end

  def run
    body = fetch_fellowships
    rows = body.fetch("data")

    ActiveRecord::Base.transaction do
      rows.each { |row| upsert(row) }
    end

    Result.new(count: rows.size, master_updated_at: body["updated_at"])
  end

  private

  def fetch_fellowships
    uri = URI.parse("#{@base_url}/api/fellowships")
    response = Net::HTTP.get_response(uri)
    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "masters /api/fellowships returned #{response.code}"
    end

    JSON.parse(response.body)
  end

  # enabled / display_order は同期で触らない (運用フラグ・並び順は liberation 側で持つ)。
  # region_id は新規取り込み時のみデフォルトを入れる。
  # color_code は master の値で常に上書き (master が source of truth)。
  def upsert(row)
    fellowship = Fellowship.find_or_initialize_by(id: row.fetch("id"))
    fellowship.name = row["short_name"].presence || row["name"]
    fellowship.color_code = row["color_code"]
    fellowship.active = row["active"].to_i == 1
    fellowship.region_id ||= DEFAULT_REGION_ID
    fellowship.display_order ||= 0
    fellowship.save!
  end
end
