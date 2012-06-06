module LLVM
  module Script
    # A wrapper around a LLVM::Function.
    class Function < ScriptObject
    
      # The type of this function, a LLVM::FunctionType.
      attr_reader :type
      
      # The library this function is contained in.
      attr_reader :library
      
      # An array containing the type of each arg of the function.
      attr_reader :arg_types
      
      # The return block of the function, if it exists.
      attr_reader :return_block
      
      # The current return value (can only be used when defining/building the function).
      attr_reader :return_val
      
      # The type of value this function returns.
      attr_reader :return_type
    
      # @private
      def initialize(lib, mod, name, args, ret, &block)
        @library = lib
        @module = mod
        @return_type = ret
        if args.last == Types::VARARGS
          args.pop
          @type = LLVM::Function(args, ret, :varargs => true)
          @varargs = true
        else
          @type = LLVM::Function(args, ret)
        end
        @arg_types = args
        @raw = @module.functions.add(name, @type)
        build(&block) if ::Kernel.block_given?
      end
    
      # @private
      def to_ptr
        @raw.to_ptr
      end
    
      # Builds the function using the given block. The block is instance evaluated by a Generator.
      # @param [Proc] block The insides of the function.
      def build(&block)
        @generator ||= Generator.new(@library, @module, self)
        return if @generator.finished?
        @generator.instance_exec(*self.args, &block)
        if @generator.basic_block.empty?
          @generator.basic_block.dispose
        end
        @return_block.move_after(@raw.basic_blocks.last) unless  @return_block.nil?
        unless @generator.finished?
          warn("#{name.to_s.capitalize} has no return at the end of the function!")
        end
        @generator.finish
      end
    
      # The array of args (LLVM::Values) passed to the function.
      # @return [Array<LLVM::Value>] The function's arguments.
      def args
        return @raw.params
      end
      
      # Whether the function takes a variable number of arguments
      # @return [Boolean] The resulting true/false value.
      def varargs?
        return @varargs
      end
    
      # Bitcasts (changing type without modifying bits) this function to the given type.
      # @param [LLVM::Type] type The type to bitcast to.
      # @return [LLVM::Value] The resulting function of the new type.
      def bitcast(type)
        @raw.bitcast_to(type)
      end
      
      # This function's type wrapped in a pointer.
      # @return [LLVM::Type] A LLVM::Type representing a pointer to this function's type.
      def pointer
        LLVM::Pointer(@type)
      end
    
      # Adds a LLVM::BasicBlock to the function with the given name.
      # @param [String] name Name of the basic block in LLVM IR.
      # @return [LLVM::BasicBlock] The new basic block
      def add_block(name="")
        @raw.basic_blocks.append(name)
      end
    
      # Creates the return block. This is usually only used internally by the Generator.
      def setup_return
        return if @generator.nil?
        return unless @return_val.nil?
        @return_block = @raw.basic_blocks.append("return")
        builder = LLVM::Builder.new
        instruction = @generator.start_block.instructions.first
        instruction ? builder.position_before(instruction) : builder.position_at_end(@generator.start_block)
        @return_val = builder.alloca(@return_type, "retval")
        builder.position_at_end(@return_block)
        if @return_type == VOID
          builder.ret_void
        else
          builder.ret(builder.load(@return_val))
        end
        builder.dispose
      end
    
      # Passes unknown methods to the internal LLVM::Function.
      def method_missing(sym, *args, &block)
        if @raw.respond_to?(sym)
          @raw.__send__(sym, *args, &block)
        else
          super(sym, *args, &block)
        end
      end
    
      # Checks for unknown methods in the internal LLVM::Function.
      def respond_to?(sym, *args, &block)
        return true if @generator.respond_to?(sym)
        super(sym, *args, &block)
      end
    end
  end
end