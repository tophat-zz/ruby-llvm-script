module LLVM
  module Script 
    if /^1\.9/  === RUBY_VERSION  
      #
      # This class does nothing on non-Ruby 1.9.x platforms. 
      # 
      # On Ruby 1.9.x, however, it inherits BasicObject. This allows it to ignore default 
      # Kernel methods unless the method is missing. This allows you not to have to self.methodname 
      # syntax when a Library or Program function name conflicts with a Kernel function. An example of 
      # this is in the {https://github.com/tophat/ruby-llvm-script/wiki/Hello-World hello world program}.
      #
      class ScriptObject < BasicObject
        # Makes LLVM available to the object system
        LLVM = ::LLVM
        
        # Needed in order to get the class of a ScriptObject.
        def class
          (class << self; self end).superclass
        end
        
        # Needed for class testing of a ScriptObject.
        def instance_of?(klass)
          return self.class == klass
        end
        
        # Needed for ancestor testing of a ScriptObject.
        def kind_of?(mod)
          self.class.ancestors.include?(mod)
        end
        
        # Tries to get unknown constants from Object.
        def self.const_missing(name)
          ::Object.const_get(name)
        end
        
        # Passes unknown methods to Kernel.
        def method_missing(sym, *args, &block)
          super unless ::Kernel.respond_to?(sym)
          ::Kernel.__send__(sym, *args, &block)
        end
        
        # Checks for unknown methods in Kernel.
        def respond_to_missing?(name, include_private = false)
          ::Kernel.respond_to?(name, include_private) || super
        end   
      end
    else
      class ScriptObject < Object; end
    end
  end
end