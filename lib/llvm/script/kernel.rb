include LLVM::Script::Types

# Adds some ease-of-use functions to Kernel. It also includes {LLVM::Script::Types}.
module Kernel
  # @!macro [new] factory
  #   Creates a new $0 or adds to it if one with the given name already exists. If this is 
  #   called without a name, it returns the last created namespace in the {LLVM::Script::DEFAULT_SPACE} or 
  #   nil if none have yet to be created. Otherwise, calls {LLVM::Script::Namespace#$0} on the 
  #   {LLVM::Script::DEFAULT_SPACE}.
  #   @param [Symbol, String] $1 A name for the new $0.
  #   @param [Proc] block An optional block instance to build the new $0 with.
  #   @return (see LLVM::Script::Namespace#$0)
  #   @see LLVM::Script::Namespace#$0
  def namespace(name="", &block)
    return LLVM::Script::DEFAULT_SPACE.last if name.empty?
    return LLVM::Script::DEFAULT_SPACE.namespace(name, &block)
  end
  
  # Gets a hash of all namespaces in the {LLVM::Script::DEFAULT_SPACE}.
  # @return [Hash<Symbol, LLVM::Script::Namespace>] A hash where a symbol name corresponds to a namespace. 
  def namespaces
    return LLVM::Script::DEFAULT_SPACE.children
  end
  
  # @macro factory
  def library(name="", opts={}, &block)
    return LLVM::Script::DEFAULT_SPACE.last if name.empty?
    return LLVM::Script::DEFAULT_SPACE.library(name, &block)
  end
  
  # @macro factory
  def program(name="", &block)
    return LLVM::Script::DEFAULT_SPACE.last if name.empty?
    return LLVM::Script::DEFAULT_SPACE.program(name, &block)
  end
end