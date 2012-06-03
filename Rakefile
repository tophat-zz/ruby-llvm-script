require 'rubygems'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rdoc/task'

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.rcov_opts << "--exclude gems"
    t.test_files = FileList["test/**/*_test.rb"]
  end
rescue LoadError
  warn "Proceeding without Rcov. gem install rcov on supported platforms."
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/tc_*.rb"]
end

begin
  require 'yard'

  YARD::Rake::YardocTask.new do |t|
    t.options = %W[--no-private]
    t.files = [(Dir['lib/**/*.rb'] - ['lib/llvm/ext.rb', 'lib/llvm/linker.rb']), "-", "LICENSE"].flatten
  end
rescue LoadError
  warn "Yard is not installed. `gem install yard` to build documentation."
end

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  
  s.name = 'ruby-llvm-script'
  s.version = '1.0.0'
  s.summary = "Simple, clean interface for ruby-llvm."
  s.description = s.summary
  s.author = "Mac Malone"
  s.homepage = "http://github.com/tophat/ruby-llvm-script"
  
  s.requirements << "LLVM v3.0"
  s.add_dependency('ruby-llvm', '>= 3.0.0')
  s.files = Dir['lib/**/*.rb'] + Dir['samples/*.rb'] + Dir["ext/**/*"]
  s.require_path = 'lib'
  s.extensions << "ext/linker/Rakefile"
  
  s.test_files = Dir["test/**/*.rb"]
  
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE']
end

Rake::GemPackageTask.new(spec) do |t|
end

task :generate_ffi do
  require 'ffi_gen'
  
  FFIGen.generate(
    :module_name => "LLVM::C",
    :ffi_lib     => "LLVM-3.0",
    :headers     => ["linker.h"],
    :cflags      => `llvm-config --cflags`.split(" "),
    :prefixes    => ["LLVM"],
    :blacklist   => ["LLVMGetMDNodeNumOperands", "LLVMGetMDNodeOperand",
                    "LLVMInitializeAllTargetInfos", "LLVMInitializeAllTargets", "LLVMInitializeNativeTarget"],
    :output      => "lib/llvm/linker_ffi.rb"
  )
end

task :default => [:test]
