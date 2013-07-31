$LOAD_PATH.unshift File.expand_path 'lib', __dir__
require 'jsonite/version'

Gem::Specification.new do |s|
  s.name        = 'jsonite'
  s.version     = Jsonite::VERSION
  s.summary     = 'Tiny JSON presenter'
  s.description = 'Tiny JSON presenter'

  s.files       = Dir['lib/**/*']

  s.has_rdoc    = false

  s.authors     = ['Stephen Celis', 'Evan Owen']
  s.email       = %w[stephen@stephencelis.com kainosnoema@gmail.com]
  s.homepage    = 'https://github.com/barrelage/jsonite'

  s.required_ruby_version = '>= 1.9.3'

  s.add_dependency 'activesupport', '>= 3.1.0'
end
