# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "avm_shell/version"

Gem::Specification.new do |s|
  s.name        = "avm_shell"
  s.version     = AvmShell::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Chris Ochs"]
  s.email       = ["snacktime@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{summary}
  s.description = %q{description}

  s.rubyforge_project = "avm_shell"

  s.files         = `git ls-files lib`.split("\n")
  #s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  #s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
