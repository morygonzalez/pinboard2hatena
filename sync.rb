require 'bundler'
Bundler.require(:default, :sync)
require 'logger'
require 'hatena/bookmark/restful/v1'
Dotenv.load

Process.daemon(true, true)

logger = Logger.new(File.expand_path(File.join(File.dirname(__FILE__), 'log', 'sync.log')))

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

Signal.trap('QUIT') {
  t = Thread.new do
    logger.info "Server #{Process.pid} killed"
    logger.close
  end
  t.join
  Process.kill 'QUIT', $$
}

Signal.trap('TERM') {
  t = Thread.new do
    logger.info "Server #{Process.pid} killed"
    logger.close
  end
  t.join
  Process.kill 'QUIT', $$
}

logger.info "Started process #{Process.pid}"

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

      logger.debug params

      begin
        hatena_client.create_bookmark(params)
      rescue JSON::ParserError
        params.delete(:tags)
        hatena_client.create_bookmark(params)
      rescue => error
        logger.error "Bookmark failed!!! #{b.description} - #{b.href}"
        logger.error error.message
        logger.error error.backtrace
      ensure
        last_checked_entry_time = b.time
      end

      if error.nil?
        logger.info "Bookmark success!!! #{b.description} - #{b.href}"
        # last_checked_entry_time = b.time
      end

      sleep 5
    end
  rescue NoMethodError, SocketError, Net::OpenTimeout => e
    logger.warn "#{e.inspect}"
    sleep 60 * 10
    next
  end

  sleep 60 * 10
end
