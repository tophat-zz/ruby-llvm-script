require 'rubygems'
require 'rake/testtask'
require 'rubygems/package_task'
require 'rdoc/task'

begin
  import 'Quality.rake'
rescue Exception
  warn "Proceeding without quality tests. Install flay, flog, and reek gems for code quality testing."
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

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.rcov_opts << "--exclude gems" << "--exclude 'lib/llvm/ext.rb'" << "--exclude 'lib/llvm/script/core.rb'"
    t.test_files = FileList["test/**/tc_*.rb"]
  end
rescue LoadError
  warn "Proceeding without Rcov. `gem install rcov` on supported platforms."
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = (FileList["test/**/tc_*.rb"] - ['lib/llvm/ext.rb', 'lib/llvm/linker.rb'])
end
task :default => [:test]
