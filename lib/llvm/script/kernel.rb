include LLVM::Script::Types

# Adds some ease-of-use functions to Kernel. It also includes {LLVM::Script::Types}.
module Kernel
  # Creates a new program with the given options and an optional name. If this is 
  # called without a block and with no arguments, it returns the last created program or nil if none.
  # If called without a block and with a name, returns the program with that name or nil if none.
  # @param (see LLVM::Script::Program#initialize)
  # @option (see LLVM::Script::Program#initialize)
  # @return [LLVM::Script::Program] The new program.
  # @see LLVM::Script::Program#initialize  
  def program(name="", opts={}, &block)
    unless block_given?
      return LLVM::Script::Program.lookup(name)
    else
      return LLVM::Script::Program.new(name, opts, &block)
    end
  end
  
  # (see LLVM::Script::Program.programs)
  def programs
    return LLVM::Script::Program.programs
  end
  
  # Creates a new library with the given options and an optional name. If this is 
  # called without a block and with no arguments, it returns the last created library or nil if none.
  # If called without a block and with a name, returns the library with that name or nil if none.
  # @param (see LLVM::Script::Library#initialize)
  # @option (see LLVM::Script::Library#initialize)
  # @return [LLVM::Script::Library] The new library.
  # @see LLVM::Script::Library#initialize
  def library(name="", opts={}, &block)
    unless block_given?
      return LLVM::Script::Library.lookup(name)
    else
      return LLVM::Script::Library.new(name, opts, &block)
    end
  end
  
  # (see LLVM::Script::Library.libraries)
  def libraries
    return LLVM::Script::Library.libraries
  end
end