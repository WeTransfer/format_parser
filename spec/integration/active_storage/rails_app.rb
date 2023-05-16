require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem 'rails', '6.0.3'
  gem 'sqlite3'
  gem 'format_parser', path: './'
end

require 'active_record/railtie'
require 'active_storage/engine'
require 'tmpdir'

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << 'example.org'
  config.eager_load = false
  config.session_store :cookie_store, key: 'cookie_store_key'
  secrets.secret_key_base = 'secret_key_base'

  config.logger = Logger.new('/dev/null')

  config.active_storage.service = :local
  config.active_storage.service_configurations = {
    local: {
      root: Dir.tmpdir,
      service: 'Disk'
    }
  }

  config.active_storage.analyzers.prepend FormatParser::ActiveStorage::BlobAnalyzer
end

ENV['DATABASE_URL'] = 'sqlite3::memory:'

Rails.application.initialize!

require ActiveStorage::Engine.root.join('db/migrate/20170806125915_create_active_storage_tables.rb').to_s

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change

  create_table :users, force: true
end

class User < ActiveRecord::Base
  has_one_attached :profile_picture
end

require 'minitest/autorun'
require 'open-uri'

fixtures_dir = File.join(File.dirname(__FILE__), '../../fixtures')

describe User do
  describe "profile_picture's metadatas" do
    it 'parse metadatas with format_parser' do
      fixture_path = fixtures_dir + '/PNG/cat.png'
      user = User.create
      user.profile_picture.attach(
        filename: 'cat.png',
        io: File.open(fixture_path, 'rb')
      )

      user.profile_picture.analyze

      _(user.profile_picture.metadata[:width_px]).must_equal 600
      _(user.profile_picture.metadata[:height_px]).must_equal 600
      _(user.profile_picture.metadata[:color_mode]).must_equal 'rgba'
    end
  end
end
