$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'

FILE = LLVM::Script::Struct.new("FILE")
FILEPTR = FILE.pointer

library 'stdio' do  
  extern :fdopen, [INT, CHARPTR], FILEPTR
  extern :printf, [CHARPTR, VARARGS], INT
  extern :fgets, [CHARPTR, INT, FILEPTR], CHARPTR
end

program "I/O" do
  import 'stdio'
	extern :strchr, [CHARPTR, INT], CHARPTR
	
	main do
	  bufsize = 800
	  buf = alloca(CHAR, bufsize) # Allocate a pointer to a CHAR array that is bufsize
	  stdin = fdopen(0, "r") # Get the stdin stream for reading (0 - stdin, 1 - stdout, 2 - stderr)
	  self.printf("Please enter a line of text, max %d characters\n", bufsize);
    cond is_not_null(fgets(buf, bufsize, stdin)) do # Get some input and put it in buf
		   p = strchr(buf, 10) # Get a pointer to the "\n" character (ASCII 10) in the input buffer
		   cond is_not_null(p) do
		     store(0, p) # Replace the "\n" character with a "\0" (null) character (ASCII 0)
		   end
		   self.printf("Thank you, you entered >%s<\n", buf);
		end
		sret 0
	end
end

puts
program.dump

puts
program.compile("io")