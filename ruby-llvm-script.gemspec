Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  
  s.name = 'ruby-llvm-script'
  s.version = '1.0.0'
  s.summary = "Simple, clean interface for ruby-llvm."
  s.description = s.summary
  s.author = "Mac Malone"
  s.homepage = "http://tophat.github.com/ruby-llvm-script"
  
  s.requirements << "LLVM v3.0"
  s.add_dependency('ruby-llvm', '>= 3.0.0')
  s.add_development_dependency("rake")
  s.add_development_dependency("yard")
  s.add_development_dependency("flog")
  s.add_development_dependency("flay")
  s.add_development_dependency("reek")
  s.add_development_dependency("mocha")
  s.files = Dir['lib/**/*.rb'] + Dir['samples/*.rb'] + Dir["ext/**/*"]
  s.require_path = 'lib'
  s.extensions << "ext/linker/Rakefile"
  
  s.test_files = Dir["test/**/*.rb"]
  
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE']
end