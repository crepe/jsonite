$LOAD_PATH.unshift File.expand_path '../lib', __FILE__
require 'jsonite/version'

Gem::Specification.new do |s|
  s.name        = 'jsonite'
  s.version     = Jsonite::VERSION
  s.summary     = 'A tiny, HAL-compliant JSON presenter'
  s.description = 'Jsonite provides a very simple DSL to build HAL-compliant JSON presenters.'
  s.license     = 'MIT'

  s.files       = Dir['lib/**/*']

  s.has_rdoc    = false

  s.authors     = ['Stephen Celis', 'Evan Owen']
  s.email       = %w[stephen@stephencelis.com kainosnoema@gmail.com]
  s.homepage    = 'https://github.com/barrelage/jsonite'

  s.required_ruby_version = '>= 1.9.3'

  s.add_dependency 'activesupport', '>= 3.1.0'

  s.add_development_dependency 'activemodel', '>= 3.1.0'
  s.add_development_dependency 'rake', '= 10.1.0'
  s.add_development_dependency 'rspec', '= 2.14.1'
end
