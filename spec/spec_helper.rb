require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'format_parser'
require 'pry'

module SpecHelpers
  def fixtures_dir
    __dir__ + '/fixtures/'
  end
end

RSpec.configure do |c|
  c.include SpecHelpers
  c.extend SpecHelpers # makes fixtures_dir available for example groups too
end
