require 'bundler'
require 'erb'
Bundler.require(:sync)
require 'hatena/bookmark/restful/v1'
Dotenv.load

pinboard = Pinboard::Client.new(:token => ENV['PINBOARD_TOKEN'])

credentials = Hatena::Bookmark::Restful::V1::Credentials.new(
  consumer_key:        ENV['CONSUMER_KEY'],
  consumer_secret:     ENV['CONSUMER_SECRET'],
  access_token:        ENV['ACCESS_TOKEN'],
  access_token_secret: ENV['ACCESS_TOKEN_SECRET']
)

class Hatena::Bookmark::Restful::V1
  def create_bookmark(bookmark_params)
    res = connection.post("/#{api_version}/my/bookmark") {|req|
      req.params = bookmark_params
    }
    attrs = JSON.parse(res.body)
    bookmark = Bookmark.new_from_response(attrs)
  end

  private

  def connection
    @connection ||= Faraday.new(url: 'http://api.b.hatena.ne.jp/') do |conn|
      conn.request :url_encoded
      conn.options.params_encoder = Faraday::FlatParamsEncoder
      conn.request     :oauth, {
        consumer_key:    @credentials.consumer_key,
        consumer_secret: @credentials.consumer_secret,
        token:           @credentials.access_token,
        token_secret:    @credentials.access_token_secret
      }
      conn.headers['User-Agent'] = 'Hatena::Bookmark::Restful Client'
      conn.adapter Faraday.default_adapter
    end
  end
end

hatena_client = Hatena::Bookmark::Restful::V1.new(credentials)

loop do
  last_checked_entry_time ||= Time.now

  recent_bookmarks = pinboard.recent
  recent_bookmarks.reverse!
  recent_bookmarks.each do |b|
    next if last_checked_entry_time > b.time

    error = nil
    params = {
      url:     b.href,
      comment: b.extended,
      tags: b.tag
    }
    if b.shared == "no"
      params[:private] = true
    end
    begin
      hatena_client.create_bookmark(params)
    rescue => error
      ap "Bookmark failed!!! #{b.description} - #{b.href}"
      ap error.message
      ap error.backtrace
    end

    if error.nil?
      ap "Bookmark success!!! #{b.description} - #{b.href}"
    end

    last_checked_entry_time = b.time
    sleep 30
  end

  sleep 60 * 5
end