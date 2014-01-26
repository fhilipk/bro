$:.push File.expand_path("../lib", __FILE__)
require 'dog/version'

Gem::Specification.new do |s|
  s.name        = 'dogpages'
  s.version     = dog::VERSION
  s.date        = '2013-12-21'
  s.summary     = "dog"
  s.description = "Highly readable supplement to man pages. Shows simple, concise examples for unix commands."
  s.authors     = ["bropages.org"]
  s.email       = 'info@bropages.org'
  s.files       = [ "lib/dog.rb", 
                    "lib/dog/state.rb",
                    "lib/dog/dog_state.rb",
                    "lib/dog/string_hacks.rb",
                    "lib/dog/version.rb"]
  s.homepage    = 'http://bropages.org'
  s.executables << 'dog'
  s.add_runtime_dependency 'json_pure', '1.8.1'
  s.add_runtime_dependency 'commander', '4.1.5'
  s.add_runtime_dependency 'rest-client'
  s.add_runtime_dependency 'smart_colored'
  s.add_runtime_dependency 'highline', '1.6.20'
  s.add_runtime_dependency 'mime-types', '1.19'
end
