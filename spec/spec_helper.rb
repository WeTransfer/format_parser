require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
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
  # https://relishapp.com/rspec/rspec-core/docs/command-line/only-failures
  c.example_status_persistence_file_path = 'spec/examples.txt'
end

RSpec.shared_examples 'an IO object compatible with IOConstraint' do
  it 'responds to the same subset of public instance methods' do
    requisite_methods = FormatParser::IOConstraint.public_instance_methods - Object.public_instance_methods
    requisite_methods.each do |requisite|
      expect(described_class.public_instance_methods).to include(requisite), "#{described_class} must respond to #{requisite}"
    end
  end
end
