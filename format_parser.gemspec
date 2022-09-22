
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'format_parser/version'

Gem::Specification.new do |spec|
  spec.name          = 'format_parser'
  spec.version       = FormatParser::VERSION
  spec.authors       = ['Noah Berman', 'Julik Tarkhanov']
  spec.email         = ['noah@noahberman.org', 'me@julik.nl']
  spec.licenses      = ['MIT (Hippocratic)']
  spec.summary       = 'A library for efficient parsing of file metadata'
  spec.description   = "A Ruby library for prying open files you can convert to a previewable format, such as video, image and audio files. It includes
  a number of parser modules that try to recover metadata useful for post-processing and layout while reading the absolute
  minimum amount of data possible."
  spec.homepage      = 'https://github.com/WeTransfer/format_parser'
  spec.license       = 'MIT (Hippocratic)'
  spec.required_ruby_version = '>= 2.7'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    # Make sure large fixture files are not packaged with the gem every time
    f.match(%r{^spec/fixtures/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'ks'
  spec.add_dependency 'exifr', '>= 1.3.8'
  spec.add_dependency 'id3tag', '>= 0.14.2'
  spec.add_dependency 'faraday', '>= 1', '<3'
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'measurometer'

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'wetransfer_style', '1.0.0'
  spec.add_development_dependency 'parallel_tests'
end
