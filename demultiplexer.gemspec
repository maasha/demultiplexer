$LOAD_PATH.push File.expand_path('../lib', __FILE__)

require 'demultiplexer/version'

Gem::Specification.new do |s|
  s.name              = 'demultiplexer'
  s.version           = Demultiplexer::VERSION
  s.platform          = Gem::Platform::RUBY
  s.date              = Time.now.strftime('%F')
  s.summary           = 'Demultiplexer'
  s.description       = 'Demultiplex sequences from the Illumina platform.'
  s.authors           = ['Martin A. Hansen']
  s.email             = 'mail@maasha.dk'
  s.rubyforge_project = 'demultiplexer'
  s.homepage          = 'http://github.com/maasha/demultiplexer'
  s.license           = 'GPL2'
  s.rubygems_version  = '2.0.0'
  s.executables       << 'demultiplexer'
  s.files             = `git ls-files`.split("\n")
  s.test_files        = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths     = ['lib']

  s.add_dependency('biopieces',             '>= 0.4.1')
  s.add_dependency('google_hash',           '>= 0.8.4')
  s.add_development_dependency('bundler',   '>= 1.7.4')
  s.add_development_dependency('simplecov', '>= 0.9.2')
end
