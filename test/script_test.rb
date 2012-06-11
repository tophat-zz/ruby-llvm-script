$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

begin
  require "ruby-debug"
rescue LoadError
  # Ignore ruby-debug is case it's not installed
end

require 'llvm/script'
require "minitest/autorun"
require 'tempfile'
require 'mocha'

class MiniTest::Unit::TestCase
  
  def capture_stderr
    old = $stderr.dup
    file = Tempfile.new("log.txt")
    $stderr.reopen(file.path)
    $stderr.sync = true
    yield
    $stderr = old
    out = File.read(file.path)
    file.close!
    return out
  end
  
  def refute_silent
    out, err = capture_io { yield }
    refute (out.empty? && err.empty?), "Expected stdout or stderr to not be silent."
  end
  
end