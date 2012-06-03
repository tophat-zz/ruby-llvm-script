$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'

program "Function Pointers" do
  f = function :f, [INT], INT do |n|
    sret add(n, 1)
  end
  
  function :g, [f.pointer, INT], INT do |fp, n|
    sret call(fp, n)
  end
  
  main do
    sret g(f, 41)
  end
end

fp = program("Function Pointers")
fp.verify

puts
fp.dump

puts "\ng(f(41)) = #{fp.run.to_i}\n\n"
    