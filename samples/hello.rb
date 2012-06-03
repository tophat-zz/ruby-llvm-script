$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'

program "Hello World" do
	extern :printf, [CHARPTR, VARARGS], INT
	
	main do
	  # self.x neccesary for Ruby 1.8.x users when Kernel conflicts arise
		self.printf("Hello World")
		sret 0
	end
end

puts
program.dump

puts
program.run