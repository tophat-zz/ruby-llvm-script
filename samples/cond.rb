$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'

FILE = LLVM::Script::Struct.new("FILE")
FILEPTR = FILE.pointer

program "Conditionals" do
  extern :atoi, [CHARPTR], INT
	extern :printf, [CHARPTR, VARARGS], INT
	extern :fdopen, [INT, CHARPTR], FILEPTR
  extern :fgets, [CHARPTR, INT, FILEPTR], CHARPTR
	
	main do
	  buf = alloca(CHAR, 20)
	  stdin = fdopen(0, "r")
    self.printf("Please input a non-zero number: ")
    num = atoi(fgets(buf, 20, stdin))
    cond opr(:eq, num, 0), proc {
      self.printf("You entered a zero! Bad boy!\n")
    }, proc {
      self.printf("You entered %d, which is not 0! Good boy!\n", num)
    }
    sret 0
	end
end

puts
program.dump

puts
program.compile("cond")