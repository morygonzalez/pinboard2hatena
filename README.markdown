# pinboard2hatena

## What does this program do?

Synchronize はてなブックマーク with Pinboard.

## Usage

1. `bundle install`
2. Register はてな API as OAuth Consumer.
  - http://www.hatena.ne.jp/oauth/develop
3. `cp .env{.sample,}`
4. Add consumer token and secret to `.env`, then run sinatra app with `bundle exec ruby app.rb`.
5. Access localhost:4567 with your browser and get access token and secret.
6. Add access token and secret to `.env`.
7. Get Pinboard API token, then add to `.env`.
  - https://pinboard.in/settings/password
8. Then `bundle exec ruby sync.rb`.
