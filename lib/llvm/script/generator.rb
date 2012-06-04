module LLVM
  module Script
    # The heart of ruby-llvm-script. The Generator class is a greatly enhanced form of a LLVM::Builder. 
    # * Smart conversion of Ruby objects into their LLVM equivalents. 
    # * Raises descriptive errors on the Ruby level to prevent as many indiscernible errors 
    #   (like segementation faults) as possible.
    # * Makes LLVM::Script functions, macros, and globals into methods.
    class Generator < ScriptObject
    
      # The library in which this Generator's function is contained.
      attr_reader :library
      
      # The function inside which the Generator builds.
      attr_reader :function
      
      # Inside a {#lp} statement this value is set to the block which contains the loop.
      # This is set internally, please do not change it.
      attr_accessor :loop_block
      
      # The current LLVM::BasicBlock of the Generator.
      attr_reader :basic_block
      
      # The LLVM::BasicBlock the Generator started in. Outside {#cond} and {#lp} statements
      # this is the function's entry block. Inside {#cond} and {#lp} statements this is the
      # block being generated (cond - an if or else block, lp - the loop or increment block).
      attr_reader :start_block
    
      # @private
      def initialize(lib, mod, function, block=nil)
        @library = lib
        @module = mod
        @function = function 
        @basic_block = block || @function.add_block("entry")
        @start_block = @basic_block
        @builder = LLVM::Builder.new
        @builder.position_at_end(@basic_block)
        @finished = false
      end
      
      # @private
      def to_ptr
        @start_block.to_ptr
      end
    
      # Gets the generator's function's args.
      # @return [Array<LLVM::Value>] The function's arguments.
      # @see LLVM::Script::Function#args    
      def args
        @function.args
      end
    
      # Calls callable with the given args.
      # @param [LLVM::Value, LLVM::Script::Function, String, Symbol] callable The value to call.
      #   If a String or Symbol, tries to call a function or macro of the Generator's library with
      #   the given name. If a LLVM::Value or LLVM::Script::Function, calls it directly.
      # @param [List<Values>] args A list of values (LLVM::Values or Ruby equivalents) to pass to
      #   the callable.
      # @return [Object] The return value of the function (always a LLVM::Value) or macro (could be anything).
      def call(callable, *args)
        if callable.is_a?(String) || callable.is_a?(Symbol)
          proc = @library.macros(true)[callable.to_sym]
          fun = @library.functions(true)[callable.to_sym]
          if proc
            count = proc.arity >= 0 ? proc.arity : 0
            if args.count != count
              raise ArgumentError, "Wrong number of arguments passed to macro (#{args.count} for #{count})" 
            end
            self.instance_exec(*args, &proc)
          elsif fun
            @builder.call(fun, *args.map{|a| convert(a, fun.arg_types[args.index(a)])})
          else
            raise NoMethodError, "Function or macro, '#{function.to_s}', does not exist."
          end
        elsif callable.kind_of?(LLVM::Script::Function)
          @builder.call(callable, *args.map{|a| convert(a, fun.arg_types[args.index(a)])})
        elsif callable.kind_of?(LLVM::Value)
          @builder.call(callable, *args.map{|a| convert(a)})
        else
          raise ArgumentError, "Callable passed to call must be a LLVM::Value or a name of a Library function or macro."
        end
      end
    
      # Gets a pointer to the global with the given name.
      # @param [String, Symbol] name The name of the global.
      # @return [LLVM::Value] A pointer to the global.
      def global(name)
        return @library.globals(true)[name.to_sym]
      end
      
      # Changes a numeric's sign (positive to negative, negative to positive).
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v The numeric to change sign.
      # @return [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] The resulting numeric of the opposite sign.
      def neg(v)
        @builder.neg(convert(v))
      end
    
      # Increments the numeric pointed to by a pointer by the given amount.
      # @param [LLVM::Value] ptr The numeric pointer to increment.
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] a The amount to add. 
      def inc(ptr, a=1)
        val = @builder.load(ptr)
        @builder.store(add(val, convert(a)), ptr)
      end
    
      # Decrements the numeric pointed to by a pointer by the given amount.
      # @param [LLVM::Value] ptr The integer pointer to decrement.
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] a The amount to subtract.
      def dec(ptr, a=1)
        val = @builder.load(ptr)
        @builder.store(sub(val, convert(a)), ptr)
      end
    
      # Adds the two numeric values together (two integers or two floats). (<tt>v1 + v2</tt>)
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v1 The first numeric.
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v2 The second numeric.
      # @return [LLVM::ConstantInt, LLVM::ConstantReal]  The numeric sum.
      def add(v1, v2)
        val = convert(v1)
        case v1.type.kind
        when :integer
          @builder.add(val, convert(v2, v1.type))
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fadd(val, convert(v2, v1.type))
        else
          raise ArgumentError, "Value passed to add is not Numeric."
        end
      end
    
      # Subtracts the second numeric from the first (two integers or two floats). (<tt>v1 - v2</tt>)
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v1 The numeric to be subtracted from (minuend).
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v2 The numeric to subtract (subtrahend).
      # @return [LLVM::ConstantInt, LLVM::ConstantReal]  The numeric difference.
      def sub(v1, v2)
        val = convert(v1)
        case v1.type.kind
        when :integer
          @builder.sub(val, convert(v2, v1.type))
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fsub(val, convert(v2, v1.type))
        else
          raise ArgumentError, "Value passed to sub is not Numeric."
        end
      end
    
      # Multiplys two numerics together (two integers or two floats). (<tt>v1 * v2</tt>)
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v1 The first numeric.
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v2 The second numeric.
      # @return [LLVM::ConstantInt, LLVM::ConstantReal]  The numeric product.
      def mul(v1, v2)
        val = convert(v1)
        case v1.type.kind
        when :integer
          @builder.mul(val, convert(v2, v1.type))
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fmul(val, convert(v2, v1.type))
        else
          raise ArgumentError, "Value passed to mul is not Numeric."
        end
      end
      
      # Divides the first numeric by the second (two integers or two floats). (<tt>v1 / v2</tt>)
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v1 The numeric to be divided (dividend).
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v2 The numeric to divide by (divisor).
      # @param [Boolean] signed Whether any of numerics can be negative.
      # @return [LLVM::ConstantInt, LLVM::ConstantReal]  The numeric quotient.
      # @raise [ZeroDivisionError] Raised if the second numeric (v2) is 0.
      def div(v1, v2, signed=true)
        raise ZeroDivisionError if v2 == 0
        val = convert(v1)
        case v1.type.kind
        when :integer
          if signed
            @builder.div(val, convert(v2, v1.type))
          else
            @builder.udiv(val, convert(v2, v1.type))
          end
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fdiv(val, convert(v2, v1.type))
        else
          raise ArgumentError, "Value passed to div is not Numeric."
        end
      end
      
      # Finds the remainder of the first numeric by the second (two integers or two floats). (<tt>v1 % v2</tt>)
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v1 The numeric to be divided (dividend).
      # @param [LLVM::ConstantInt, LLVM::ConstantReal, Numeric] v2 The numeric to divide by (divisor).
      # @param [Boolean] signed Whether any of numerics can be negative.
      # @return [LLVM::ConstantInt, LLVM::ConstantReal]  The numeric remainder.
      # @raise [ZeroDivisionError] Raised if the second numeric (v2) is 0.
      def rem(v1, v2, signed=true)
        raise ZeroDivisionError if v2 == 0
        val = convert(v1)
        case v1.type.kind
        when :integer
          if signed
            @builder.rem(val, convert(v2, v1.type))
          else
            @builder.urem(val, convert(v2, v1.type))
          end
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.frem(val, convert(v2, v1.type))
        else
          raise ArgumentError, "Value passed to rem is not Numeric."
        end
      end
    
      # Shifts the bits of the given integer the given amount to the left, replacing those bits with 0. 
      # (<tt>v1 << v2</tt> in C)
      # @param [LLVM::ConstantInt, Integer] v The integer to shift left.
      # @param [LLVM::ConstantInt, Integer] bits The the number of bits to shift left.
      # @return [LLVM::ConstantInt] The resulting integer.
      # @see http://llvm.org/docs/LangRef.html#i_shl
      # @see http://en.wikipedia.org/wiki/Bitwise_operation#Bit_shifts
      def shl(v, bits)
        @builder.shl(convert(v), convert(bits, v.type))
      end
      
      # Arithmetically shifts the bits of the given integer the given amount to the right, replacing 
      # those bits with the bit value of the sign. (0 - Negative, 1 - Positive) (<tt>v1 >> v2</tt> in C)
      # @param [LLVM::ConstantInt, Integer] v The integer to shift right.
      # @param [LLVM::ConstantInt, Integer] bits The the number of bits to shift right.
      # @return [LLVM::ConstantInt] The resulting integer.
      # @see http://llvm.org/docs/LangRef.html#i_ashr
      # @see http://en.wikipedia.org/wiki/Arithmetic_shift
      def ashr(v, bits)
        @builder.ashr(convert(v), convert(bits, v.type))
      end
      
      # Logically shifts the bits of the given integer the given amount to the right, replacing 
      # those bits with 0. (<tt>v1 >> v2</tt> in C)
      # @param [LLVM::ConstantInt, Integer] v The integer to shift right.
      # @param [LLVM::ConstantInt, Integer] bits The the number of bits to shift right.
      # @return [LLVM::ConstantInt] The resulting integer.
      # @see http://llvm.org/docs/LangRef.html#i_lshr
      # @see http://en.wikipedia.org/wiki/Logical_shift
      def lshr(v, bits)
        @builder.lshr(convert(v), convert(bits, v.type))
      end
      
      # Converts the given value into the given type without modifying bits.
      # @param [Value] v The value (an LLVM::Value or Ruby equivalent) to change type.
      # @param [LLVM::Type] type The type to change the value into.
      # @return [LLVM::Value] The resulting value of the new type.      
      def bitcast(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to bitcast must be of LLVM::Type. #{type_name(type)} given."
        end
        @builder.bit_cast(convert(v), type)
      end
      
      # Converts an integer of a bigger type into an integer of a smaller one. If the integer exceeds the
      # max size of the smaller type it will be shrunk to fit.
      # @param [LLVM::ConstantInt, Integer] v The integer to shrink.
      # @param [LLVM::Type] type The smaller type to convert the integer into.
      # @return [LLVM::Value] The resulting integer of the new type.
      def trunc(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to trunc must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case val.type.kind
        when :integer
          @builder.trunc(val, type)
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fp_trunc(val, type)
        else
          raise ArgumentError, "Value passed to trunc is not Numeric."
        end
      end
      
      # Converts an integer of a smaller type into an integer of a bigger one by copy the
      # value of the sign bit. This will result in negative numbers and booleans have their
      # values changed. To prevent the integer from changing value, use {#zext}.
      # @param [LLVM::ConstantInt, Integer] v The integer to grow.
      # @param [LLVM::Type] type The bigger type to convert the integer into.
      # @return [LLVM::Value] The resulting integer of the new type.
      def sext(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to sext must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case val.type.kind
        when :integer
          @builder.sext(val, type)
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fp_ext(val, type)
        else
          raise ArgumentError, "Value passed to trunc is not Numeric."
        end
      end
      
      # Converts an integer of a smaller type into an integer of a bigger one by adding zero value bits. 
      # In a zero extension, negative numbers and booleans keep their values unlike a {#sext signed extension}.
      # @param (see #sext)
      # @return (see #sext)
      def zext(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to zext must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case val.type.kind
        when :integer
          @builder.zext(val, type)
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fp_ext(val, type)
        else
          raise ArgumentError, "Value passed to zext is not Numeric."
        end
      end
      
      # Converts a float to an integer.
      # @param [LLVM::ConstantReal, Float] v The float to convert.
      # @param [LLVM::Type] type The type of integer to convert the float into.
      # @param [Boolean] signed Whether the integer can be negative.
      # @return [LLVM::ConstantInteger] The resulting integer.
      def ftoi(v, type, signed=true)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to ftoi must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case val.type.kind
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          if signed
            @builder.fp2si(val, type)
          else
            @builder.fp2ui(val, type)
          end
        else
          raise ArgumentError, "Value passed to ftoi is not of a float type."
        end
      end
      
      # Converts a integer to float.
      # @param [LLVM::ConstantInt, Integer] v The integer to convert.
      # @param [LLVM::Type] type The type of float to convert the integer into.
      # @param [Boolean] signed Whether the integer can be negative.
      # @return [LLVM::ConstantReal] The resulting float.
      def itof(v, type, signed=true)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to itof must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        if val.type.kind == :integer
          if signed
            @builder.si2fp(val, type)
          else
            @builder.ui2fp(val, type)
          end
        else
          raise ArgumentError, "Value passed to itof is not an integer."
        end
      end
      
      # Casts an integer, float, or pointer to a different size (ex. short to long, double to float, 
      # int pointer to array pointer, etc.).
      # @param [Value] v The value (an LLVM::Value or Ruby equivalent) to change size.
      # @param [LLVM::Type] type The different sized type to change the value into.
      # @return [LLVM::Value] The resulting value of the new size.
      def cast(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to cast must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case v.type.kind
        when :integer
          if type.kind == :integer
            @builder.int_cast(val, type)
          else
            raise ArgumentError, "Type passed to integer cast must be an integer type."
          end
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          case type.kind
          when :float, :double, :x86_fp80, :fp128, :ppc_fp128
            @builder.fp_cast(val, type)
          else
            raise ArgumentError, "Type passed to float cast must be an float type."
          end
        when :pointer
          if type.kind == :pointer
            @builder.pointer_cast(val, type)
          else
            raise ArgumentError, "Type passed to pointer cast must be an pointer type."
          end
        else
          raise ArgumentError, "Value passed to cast is not Numeric or Pointer."
        end
      end
      
      # Allocates a pointer of the given type and size. Stack allocation.
      # @param [LLVM::Type] type The type of value this pointer points to.
      # @param [LLVM::ConstantInt, Integer] size If the pointer is an array, the size of it.
      # @return [LLVM::Value] The allocated pointer.
      def alloca(type, size=nil)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to alloca must be of LLVM::Type. #{type_name(type)} given."
        end
        if size
          @builder.array_alloca(type, convert(size))
        else
          @builder.alloca(type)
        end
      end

      # Allocates a pointer of the given type and size. Heap allocation.
      # @param [LLVM::Type] type The type of value this pointer points to.
      # @param [LLVM::ConstantInt, Integer] size If the pointer is an array, the size of it.
      # @return [LLVM::Value] The allocated pointer.
      def malloc(type, size=nil)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to malloc must be of LLVM::Type. #{type_name(type)} given."
        end
        if size
          @builder.array_malloc(type, convert(size))
        else
          @builder.malloc(type)
        end
      end
      
      # Frees the given pointer (only needs to be called for malloc'd pointers).
      # @param [LLVM::Value] ptr The pointer to free.
      def free(ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The free function can only free pointers. #{type_name(ptr)} given."
        end
        @builder.free(ptr)
      end
    
      # Gets the value a pointer points to.
      # @param [LLVM::Value] ptr The pointer to load.
      # @return [LLVM::Value] The value the pointer points to.
      def load(ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The load function only accepts pointers. #{type_name(ptr)} given."
        end
        @builder.load(ptr)
      end
    
      # Stores a value into a pointer (makes it point to this value).
      # @param [Value] v The LLVM::Value or Ruby equivalent to store in the given pointer.
      # @param [LLVM::Value] ptr The pointer to store the value in.
      def store(v, ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The store function can only store values in pointers. #{type_name(ptr)} given."
        end
        @builder.store(convert(v, ptr.type.element_type), ptr)
      end
    
      # Gets a pointer to an element at the given index of a pointer to an aggregate (a struct, array, or vector). 
      # @param [LLVM::Value] ptr A pointer to the aggregate to index.
      # @param [List<LLVM::ConstantInt, Integer>] indices A list of integers that point to the exact index of 
      #   the desired element.
      # @return [LLVM::Value] A pointer to the value at the given index.
      # @see http://llvm.org/docs/GetElementPtr.html
      def gep(ptr, *indices)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The gep function can only index pointers. #{type_name(ptr)} given."
        end
        type = ptr.type.element_type
        type = type.element_type while type.kind == :pointer
        indices = indices.flatten.map do |idx|
          index = convert(idx)
        end
        @builder.gep(ptr, indices)
      end
    
      # Same as {#gep}, but also loads the pointer after finding it.
      # @param (see #gep)
      # @return [LLVM::Value] The value of element at the given index.
      def gev(obj, *indices)
        @builder.load(gep(obj, *indices))
      end
    
      # Sets the element at the given index of a pointer to an aggregate (a struct, array, or vector). 
      # @param [LLVM::Value] ptr A pointer to the aggregate to index.
      # @param [List<LLVM::ConstantInt, Integer> and a Value] args A list of integers that point to the exact 
      #   index of the desired element to change and the value (a LLVM::Value or the Ruby equivalent) to change it to.
      def sep(ptr, *args)
        val = args.pop
        element = gep(ptr, *args)
        @builder.store(convert(val, element.type.element_type), element)
      end
      
      # Inserts (adds or replaces) the given value at the given index of a aggregate or vector. 
      # @param [Value] collection The vector or aggregate (or the Ruby equivalent) to insert into.
      # @param [Value] element The value (a LLVM::Vlaue or the Ruby equivalent) to insert.
      # @param [LLVM::ConstantInt, Integer] index The index to insert at.
      def insert(collection, element, index)
        val = convert(collection)
        if value.type.kind == :vector
          @builder.insert_element(collection, convert(element, val.type.element_type), convert(index))
        else
          @builder.insert_value(collection, convert(element, val.type.element_type), convert(index))
        end
      end
      
      # Extracts a value from the given index of a aggregate or vector. 
      # @param [Value] collection The vector or aggregate (or the Ruby equivalent) to extract from.
      # @param [LLVM::ConstantInt, Integer] index The index to extract the value from.
      # @return [LLVM::Value] The extracted element.
      def extract(collection, index)
        val = convert(collection)
        if value.type.kind == :vector
          @builder.extract_element(collection, convert(index))
        else
          @builder.extract_value(collection, convert(index))
        end
      end
      
      # Inverts the given integer (a boolean in LLVM is a one-bit integer). If bigger than a bit,
      # returns what is called the {http://en.wikipedia.org/wiki/Ones'_complement one's complement}.
      # @param [LLVM::ConstantInt, Integer, Boolean] v The integer to invert.
      # @return [LLVM::ConstantInt] The resulting inverted integer.
      def invert(v)
        @builder.not(convert(v))
      end
      
      # Checks if the given value is null.
      # @param [LLVM::Value] v The value to test.
      # @return [LLVM::ConstantInt] The resulting one-bit integer boolean (0 or 1).
      def is_null(v)
        unless v.kind_of?(LLVM::Value)
          raise ArgumentError, "Value passed to is_null must be of LLVM::Value. #{type_name(v)} given."
        end
        @builder.is_null(v)
      end
      
      # Checks if the given value is NOT null.
      # @param [LLVM::Value] v The value to test.
      # @return [LLVM::ConstantInt] The resulting one-bit integer boolean (0 or 1).
      def is_not_null(v)
        unless v.kind_of?(LLVM::Value)
          raise ArgumentError, "Value passed to is_not_null must be of LLVM::Value. #{type_name(v)} given."
        end
        @builder.is_not_null(v)
      end
      
      # Executes the operation symbolized by +op+ on the two values.
      #
      # <b>Integer/Pointer Operations</b>
      #
      #   :and - and (& or &&)
      #   :or  - or (| or ||)
      #   :xor - xor (^)
      #   :eq  - equal to (==)
      #   :ne  - not equal to (!=)
      #   :ugt - unsigned greater than (>)
      #   :uge - unsigned greater than or equal to (>=)
      #   :ult - unsigned less than (<)
      #   :ule - unsigned less than or equal to (<=)
      #   :sgt - signed greater than (>)
      #   :sge - signed greater than or equal to (>=)
      #   :slt - signed less than (<)
      #   :sle - signed less than or equal to (<=) 
      #
      # <b>Float Operations</b> 
      #
      # Unordered means it will return +true+ if either value is Not a Number (NaN), ordered means it 
      # will return +false+ if either are NaN.
      #
      #   :ord - ordered
      #   :uno - unordered
      #   :oeq - ordered and equal to (==)
      #   :ueq - unordered and equal to (==)
      #   :one - ordered and not equal to (!=)
      #   :une - unordered and not equal to  (!=)
      #   :ogt - ordered and greater than (>)
      #   :ugt - unordered and greater than (>)
      #   :olt - ordered and less than (<)
      #   :ule - unordered and less than or (<)
      #   :oge - ordered and greater than or equal to (>=)
      #   :uge - unordered and greater than or equal to (>=)
      #   :ole - ordered and less than or equal to (<=)
      #   :ule - unordered and less than or equal to (<=)
      #
      # @param [Symbol] op One of the above operations symbols.
      # @param [LLVM::Value] v1 The first value (numeric or pointer).
      # @param [LLVM::Value] v2 A second value of the same type as the first.
      # @return [LLVM::ConstantInt] The resulting one-bit integer boolean (0 or 1).
      def opr(op, v1, v2)
        val = convert(v1)
        case op
        when :or
          @builder.or(val, convert(v2, val.type))
        when :xor
          @builder.xor(val, convert(v2, val.type))
        when :and
          @builder.and(val, convert(v2, val.type))
        when :eq, :ne, :ugt, :uge, :ult, :ule, :sgt, :sge, :slt, :sle
          @builder.icmp(op, val, convert(v2, val.type))
        when :oeq, :ogt, :oge, :olt, :ole, :one, :ord, :uno, :ueq, :une
          @builder.fcmp(op, val, convert(v2, val.type))
        when :ugt, :uge, :ult, :ule 
          case val.type.kind
          when :integer
            @builder.icmp(op, val, convert(v2, val.type))
          when :float, :double, :x86_fp80, :fp128, :ppc_fp128
            @builder.fcmp(op, val, convert(v2, val.type))
          else
            raise ArgumentError, "Value passed to opr is not Numeric."
          end
        else
          raise ArgumentError, "Unrecognized operation symbol passed to opr."
        end
      end
    
    
      # Creates a new block with and returns it generator.
      # @param [String] name Name of the block in LLVM IR.
      # @param [Proc] proc The proc containing the insides of the block
      # @return [Generator] The generator of the block.
      def block(name="block", &proc)
        gen = self.class.new(@module, @function, @function.add_block(name))
        gen.instance_eval(&proc)
        return gen
      end
    
      # Creates a conditional (an if/then/else) statement.
      # @example Assuming
      #   buf = alloca(CHAR, 20)
      #   printf("Please input a non-zero number: ")
      #   num = atoi(fgets(buf, 20, stdin))
      # @example If Statement
      #   cond opr(:eq, num, 0) do
      #     printf("You entered a zero! Bad boy!")
      #   end
      # @example If/Else Statement
      #   cond opr(:eq, num, 0), proc {
      #     printf("You entered a zero! Bad boy!")
      #   }, proc {
      #     printf("You entered %d, which is not 0! Good boy!", num)
      #   }
      # @param [LLVM::ConstantInt, Boolean] cond The condition, a 0 or 1 value.
      # @param [Generator, Proc] crt If the condition is true (1), this executes. 
      #   This is only not needed when a block is given.
      # @param [Generator, Proc] wrg If the condition is false (0), this executes.
      # @param [LLVM::BasicBlock] exit An optional block to exit into.
      # @param [Proc] proc This block becoms the insides of crt or wrg if either is nil.
      def cond(cond, crt=nil, wrg=nil, exit=nil, &proc)
        exit_provided = exit ? true : false
        unless crt.kind_of?(self.class)
          gen = self.class.new(@library, @module, @function, @function.add_block("then"))
          unless crt || ::Kernel.block_given?
            raise ArgumentError, "The cond function must either be given a crt argument or a block."
          end
          gen.instance_eval(&(crt ? crt : proc))
        end
        gen ||= crt
        if gen.basic_block.empty? && !exit
          exit = gen.basic_block
        else
          exit ||= @function.add_block("exit") 
          gen.br(exit)
        end
        gen.finish
        ifblock = gen.start_block
        if wrg || (crt && ::Kernel.block_given?)
          unless wrg.kind_of?(self.class)
            gen = self.class.new(@library, @module, @function, @function.add_block("else"))
            gen.instance_eval(&(wrg ? wrg : proc))
          end
          gen ||= wrg
          elsblock = gen.start_block
          gen.br(exit)
          gen.finish
        end 
        elsblock ||= exit
        exit.move_after(gen.basic_block) unless exit == gen.basic_block
        @builder.cond(cond, ifblock, elsblock)
        unless exit_provided
          @builder.position_at_end(exit)
          @basic_block = exit
        else
          self.finish
        end
      end
    
      # Creates any kind of loop statement.
      # @example For Loop (Countdown)
      #   lp 10, proc{|i| opr(:ugt, >, 0)}, proc{|i_ptr| dec(i_ptr)} do |i|
      #     printf("%d...", i)
      #   end
      #   printf("Blast Off!")
      # @example While Loop (Ask for input from +stdin+ until some is given)
      #   buf = alloca(CHAR, 100)
      #   lp nil, proc{opr(:eq, buf, nil)}, nil do
      #     fgets(buf, 100, stdin) 
      #   end
      # @example Pseudo-Infinite Loop (Wait for a 0 from +stdin+ before returning)
      #   lp do
      #     printf("Enter 0 to quit.\n")
      #     chr = fgets(buf, 1, stdin)
      #     cond opr(:eq, atoi(chr), 0) do
      #       ret
      #     end
      #   end
      # @param [Array<Value>] vars A list of values (LLVM::Value or the Ruby equivalent) to create pointers of.
      #   It can also just be a single value.
      # @param [Proc] cmp A proc that returns (literally, not using and form of +ret+ or +return+) a 0 or 1 boolean.
      #   If this is not the given, the loop becomes infinte unless broken. The proc is passed the values or +vars+
      # @param [Proc] inc A proc that executes a the end of each loop, usually to increment some value. 
      #   The proc is passed pointers to the given +vars+.
      # @param [LLVM::BasicBlock] exit An optional block to break into.
      # @param [Proc] proc The insides of the loop. This is not required if either cmp or inc is given. 
      #   The proc is passed the values or +vars+.
      # @return [Array<LLVM::Value>] An array of pointers to +vars+. If there is just one var, returns a single 
      #   LLVM::Value of that pointer.  
      def lp(vars=nil, cmp=nil, inc=nil, exit=nil, &proc)
        ptrs = []
        exit_provided = exit ? true : false
        for var in [vars].flatten.compact
          var = convert(var)
          ptr = @builder.alloca(var.type)
          @builder.store(var, ptr)
          ptrs.push(ptr)
        end
        if cmp.nil? && inc.nil? && !::Kernel.block_given?
          raise ArgumentError, "A block, a compare proc, or a increment proc must be passed to loop."
        end
        if @basic_block.empty?
          loopblk = @basic_block
          loopblk.name = "loop"
        else
          loopblk = @function.add_block("loop")
          @builder.br(loopblk)
        end
        incblk = inc && (cmp || ::Kernel.block_given?) ? @function.add_block("increment") : loopblk
        block = ::Kernel.block_given? ? @function.add_block("block") : (inc ? incblk : loopblk)
        exit ||= @function.add_block("break")
        if ::Kernel.block_given?
          gen = self.class.new(@library, @module, @function, cmp ? block : loopblk)
          gen.loop_block = incblk
          vals = ptrs[0, proc.arity >= 0 ? proc.arity : 0].map{ |p| gen.load(p) }
          gen.instance_exec(*vals, &proc)
          gen.br(inc ? incblk : loopblk)
          gen.finish
        end
        if cmp
          gen = self.class.new(@library, @module, @function, loopblk)
          vals = ptrs[0, cmp.arity >= 0 ? cmp.arity : 0].map{ |p| gen.load(p) }
          cond = convert(gen.instance_exec(*vals, &cmp), BOOL)
          gen.builder.cond(cond, block, exit)
          gen.finish
        end
        if inc
          gen = self.class.new(@library, @module, @function, incblk)
          gen.instance_exec(*ptrs[0, inc.arity >= 0 ? inc.arity : 0], &inc)
          gen.br(loopblk)
          gen.finish
        end
        exit.move_after(gen.basic_block)
        unless exit_provided
          @builder.position_at_end(exit)
          @basic_block = exit
        else
          self.finish
        end
        return ptrs.length == 1 ? ptrs.first : ptrs
      end
    
      # Branches to the given block, finishing the current one and execute the given one.
      # @param [LLVM::BasicBlock] block The block to branch to.
      def br(block)
        return if @finished
        @builder.br(block)
        self.finish
      end
    
      # Returns the given value, creating a return block if not one already.
      # @param [Value] v The LLVM::Value or Ruby equivalent to return. Either returns void
      #   (if a the function's return type is void) or just branches to the return block if nil.
      def ret(v=nil)
        return if @finished
        if @function.return_type == VOID
          @builder.ret_void
        else
          @function.setup_return
          @builder.store(convert(v, @function.return_type), @function.return_val) unless v.nil?
          @builder.br(@function.return_block)
        end
        self.finish
      end
    
      # Returns the given value if +cond+ is true (1), creating a return block if not one already.
      # @param [LLVM::Value, Boolean] cond The condition, a 0 or 1 value.
      # @param [Value] v The LLVM::Value or Ruby equivalent to return. Either returns void
      #   (if a the function's return type is void) or just branches to the return block if nil.
      # @param [LLVM::BasicBlock] blk An optional block to exit into if +cond+ is false.
      def cret(cond, v=nil, blk=nil)
        return if @finished
        @function.setup_return
        @builder.store(convert(v, @function.return_type), @function.return_val) unless v.nil?
        cont = blk ? blk : @function.add_block("block")
        @builder.cond(cond, @function.return_block, cont)
        if blk
          self.finish
        else
          @builder.position_at_end(cont)
          @basic_block = cont
        end
      end
      
      # Returns the given value, without creating a return block.
      # @param [Value] v The LLVM::Value or Ruby equivalent to return. Can only be nil if a
      #   function's return type is void, otherwise raises an ArgumentError.
      def sret(v=nil)
        return if @finished
        if @function.return_type == VOID
          @builder.ret_void
        else
          raise ArgumentError, "Value must be passed to non-void function simple return." if v.nil?
          @builder.ret(convert(v, @function.return_type))
        end
        self.finish
      end
    
      # Creates a return block and stores the given value in the function's return value pointer,
      # but does not branch to the return block.
      # @param [Value] v The LLVM::Value or Ruby equivalent to store in the function's return value. 
      #   Can only be nil if a function's return type is void, otherwise raises an ArgumentError.
      def pret(v=nil)
        return if @finished
        @function.setup_return
        if @function.return_type == VOID
          @builder.ret_void
        else
          raise ArgumentError, "Value must be passed to non-void function pre-return." if v.nil?
          @builder.store(convert(v, @function.return_type), @function.return_val)
        end
      end
    
      # Gets the function's return block if one has been created, otherwise returns nil.
      # @return [LLVM::BasicBlock] The function's return block.
      def return_block
        return @function.return_block
      end
    
      # Checks whether the Generator is finished, meaning {#finish} has been called.
      # @return [Boolean] A true/false value.
      def finished?
        return @finished
      end
    
      # Finishes the Generator, meaning no more functions should be called. This
      # is called internally in {#br}, {#ret}, and {#sret}. It is also called if a +blk+ or +exit+
      # is provided for {#cret}, {#lp}, or {#cond}.
      def finish
        return if @finished
        @builder.dispose
        @finished = true
      end
      
      # Convience
      private
    
      def convert(v, type=nil)
        true_type = LLVM::Type(type) if !type.nil?
        type = LLVM.const_get("Int#{type.width}".to_sym) if type.kind_of?(LLVM::IntType)
        if v.kind_of?(LLVM::Value) || v.kind_of?(LLVM::Script::ScriptObject)
          return v
        elsif v.kind_of?(Numeric)
          if v == 0 && !type.nil? && true_type.kind == :pointer
            return type.null_pointer
          elsif v.kind_of?(Float) && (type.nil? || type.respond_to?(:from_f))
            return (type || FLOAT).from_f(v.to_f)
          elsif type.nil? || type.respond_to?(:from_i)
            return (type || INT).from_i(v.to_i)
          else
            raise ArgumentError, "Value passed to Generator function should be of #{type_name(type)}. Numeric given."
          end
        elsif v.kind_of?(Array)
          type ||= convert(v.first).type
          return LLVM::ConstantArray(type, v.map{|v| convert(v, type)})
        elsif v.kind_of?(String) && (type.nil? || true_type.kind == :pointer)
          str = @library.string(v)
          if str.type != type
            return @builder.bit_cast(str, type)
          else
            return @library.string(v)
          end
        elsif v == true
          return BOOL.from_i(1)
        elsif v == false
          return BOOL.from_i(0)
        elsif v.nil?
          if !type.nil? && true_type.kind == :pointer
            return type.null_pointer
          else
            return BOOL.from_i(0)
          end
        else
          types = type.nil? ? "LLVM::Value, Numeric, Array, or True/False/Nil" : "#{type_name(type)} or the Ruby equivalent"
          raise ArgumentError, "Value passed to Generator function should be of #{types}. #{v.class.name} given."
        end
      end
    
      def type_name(obj)
        return obj.name if obj.is_a?(Class)
        type = obj.is_a?(LLVM::Value) ? obj.type : obj
        if type.kind_of?(LLVM::Type)
          kind = type.kind
          if kind == :pointer
            kind = type.element_type.kind while kind == :pointer
            return "#{kind.to_s.capitalize} pointer"
          else
            return kind.to_s.capitalize
          end
        else
          return type.class.name
        end
      end
    
      public
    
      # Checks for unkown methods in the functions, macros, and globals of
      # the Generator's library and calls (for functions and macros) or returns (globals) 
      # if one is found.
      def method_missing(sym, *args, &block)
        if @library.macros(true).include?(sym)
          call(sym, *args, &block)
        elsif @library.functions(true).include?(sym)
          call(sym, *args, &block)
        elsif @library.globals(true).include?(sym)
          global(sym, *args, &block)
        else
          super(sym, *args, &block)
        end
      end
    
      # Checks for unkown methods in the functions, macros, and globals of
      # the Generator's library and returns true if one is found.
      def respond_to?(sym, *args)
        return true if @library.macros(true).include?(sym)
        return true if @library.functions(true).include?(sym)
        return true if @library.globals(true).include?(sym)
        super(sym, *args)
      end   
    end
  end
end