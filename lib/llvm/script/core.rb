require 'securerandom'

module LLVM
  module Script 
    if /^1\.9/  === RUBY_VERSION  
      #
      # This class is Ruby version dependent. 
      #
      # Ruby 1.8.x::  It just provides a method to make a Uuid (Universally unique identifier).
      #
      # Ruby 1.9.x::  It inherits BasicObject, allowing it to ignore default Kernel methods unless
      #               the method is missing. This allows you not to have to self.methodname syntax 
      #               when a Library or Program function name conflicts with a Kernel function. 
      #               An example of this is in the 
      #               {https://github.com/tophat/ruby-llvm-script/wiki/Hello-World hello world program}.
      #
      class ScriptObject < BasicObject
        # On Ruby 1.9.x, makes LLVM available to the object system
        LLVM = ::LLVM
        
        # Generates a Uuid (Universally unique identifier).
        # @return [String] The uuid.
        def make_uuid
          SecureRandom.uuid
        end
        
        # Needed on Ruby 1.9.x to get the class of a BasicObject.
        def class
          (class << self; self end).superclass
        end
        
        # Needed on Ruby 1.9.x for instance_of testing of a BasicObject.
        def instance_of?(klass)
          return self.class == klass
        end
        
        # On Ruby 1.9.x, tries to get unknown constants from Object.
        def self.const_missing(name)
          ::Object.const_get(name)
        end
        
        # On Ruby 1.9.x, passes unknown methods to Kernel.
        def method_missing(sym, *args, &block)
          super unless ::Kernel.respond_to?(sym)
          ::Kernel.__send__(sym, *args, &block)
        end
        
        # On Ruby 1.9.x, checks for unknown methods in Kernel.
        def respond_to_missing?(name, include_private = false)
          ::Kernel.respond_to?(name, include_private) || super
        end   
      end
    elsif /^1\.8/ === RUBY_VERSION
      class ScriptObject < Object
        # Generates a Uuid (Universally unique identifier).
        # @return [String] The uuid.
        def make_uuid
          ary = SecureRandom.random_bytes(16).unpack("NnnnnN")
          ary[2] = (ary[2] & 0x0fff) | 0x4000
          ary[3] = (ary[3] & 0x3fff) | 0x8000
          "%08x%04x%04x%04x%04x%08x" % ary
        end
      end 
    else
      raise RuntimeError, "LLVM::Script does not support Ruby versions below 1.8."
    end
  end
end