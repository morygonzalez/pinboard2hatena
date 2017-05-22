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

hatena_client = Hatena::Bookmark::Restful::V1.new(credentials)

last_checked_entry_time ||= if ENV['LAST_CHECKED'] && ENV['LAST_CHECKED'] != ''
                              Time.parse(ENV['LAST_CHECKED']).utc
                            else
                              Time.now.utc
                            end

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
