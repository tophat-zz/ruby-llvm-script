$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'

program "Factorial" do
  function :factorial, [INT], INT do |n|
    cret opr(:eq, n, 1), 1
    ret mul(n, factorial(sub(n, 1)))
  end
  
  main do
    sret factorial(6)
  end
end

fac = program("Factorial")
fac.verify

puts
fac.dump

puts("\nfac(#{6}) = #{fac.run.to_i}\n\n")