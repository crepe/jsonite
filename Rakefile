defaults = []

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new :spec do |t|
    t.rspec_opts = ['--color', '--format progress', '--order rand']
    t.ruby_opts = ['-W2']
  end
  defaults << :spec
rescue LoadError
  warn 'RSpec not available, spec task not provided.'
end

task default: defaults
