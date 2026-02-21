source "https://rubygems.org"

gem "jekyll"

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jekyll-diagrams"
  gem "jekyll-last-modified-at"
end

gem "webrick"

# Fix segmentation fault on build
# See: https://github.com/protocolbuffers/protobuf/issues/16853#issuecomment-2583135716
gem 'google-protobuf', force_ruby_platform: true if RUBY_PLATFORM.include?('linux-musl')

