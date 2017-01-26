require 'bundler'
Bundler.require(:default, :sync)
require 'hatena/bookmark/restful/v1'
Dotenv.load

pinboard = Pinboard::Client.new(:token => ENV['PINBOARD_TOKEN'])

credentials = Hatena::Bookmark::Restful::V1::Credentials.new(
  consumer_key:        ENV['HATENA_CONSUMER_KEY'],
  consumer_secret:     ENV['HATENA_CONSUMER_SECRET'],
  access_token:        ENV['HATENA_ACCESS_TOKEN'],
  access_token_secret: ENV['HATENA_ACCESS_TOKEN_SECRET']
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
      conn.request :oauth, {
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

last_checked_entry_time ||= Time.now.utc

loop do
  begin
    recent_bookmarks = pinboard.recent
    recent_bookmarks.reverse!
    recent_bookmarks.each do |b|
      if last_checked_entry_time >= b.time
        next
      end

      error = nil
      params = {
        url:     b.href,
        comment: b.extended,
        tags:    b.tag
      }
      params[:private] = true if b.shared == 'no'

      begin
        hatena_client.create_bookmark(params)
      rescue => error
        ap "#{Time.now}: Bookmark failed!!! #{b.description} - #{b.href}"
        ap error.message
        ap error.backtrace
      end

      if error.nil?
        ap "#{Time.now}: Bookmark success!!! #{b.description} - #{b.href}"
        last_checked_entry_time = b.time
      end

      sleep 5
    end
  rescue NoMethodError, SocketError, Net::OpenTimeout => e
    ap "#{Time.now}: #{e.inspect}"
    sleep 60 * 10
    next
  end

  sleep 60 * 10
end
