# The file containing global functions of ruby-llvm-script. It includes LLVM::Script::Types

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
      if name.empty?
        return LLVM::Script::Program.last
      elsif programs.include?(name.to_sym)
        return programs[name.to_sym]
      else
        raise ArgumentError, "Program, #{name.to_s}, does not exist."
      end
    else
      prog = LLVM::Script::Program.new(name, opts, &block)
      programs[prog.name.to_sym] = prog
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
      if name.empty?
        return LLVM::Script::Library.last
      elsif libraries.include?(name.to_sym)
        return libraries[name.to_sym]
      else
        raise ArgumentError, "Library, #{name.to_s}, does not exist."
      end
    else
      lib = LLVM::Script::Library.new(name, opts, &block)
      libraries[lib.name.to_sym] = lib
    end
  end
  
  # (see LLVM::Script::Library.libraries)
  def libraries
    return LLVM::Script::Library.libraries
  end
end