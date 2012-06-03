module LLVM
  module Script
    # The heart of ruby-llvm-script. The Generator class is a greatly enhanced form of a LLVM::Builder. 
    # * Smart conversion of Ruby objects into their LLVM equivalents. 
    # * Raises descriptive errors on the Ruby level to prevent as many indiscernible errors 
    #   (like segementation faults) as possible.
    # * Makes LLVM::Script functions, macros, and globals into methods.
    class Generator < ScriptObject
    
      attr_reader :library
      attr_reader :function
      attr_reader :loop_block
      attr_reader :basic_block
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
    
      def call(function, *args)
        if function.is_a?(String) || function.is_a?(Symbol)
          proc = @library.macros(true)[function.to_sym]
          fun = @library.functions(true)[function.to_sym]
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
        elsif function.kind_of?(LLVM::Script::Function)
          @builder.call(function, *args.map{|a| convert(a, fun.arg_types[args.index(a)])})
        elsif function.kind_of?(LLVM::Value)
          @builder.call(function, *args.map{|a| convert(a)})
        else
          raise ArgumentError, "Function passed to call must be a LLVM::Value or a name of a Library function."
        end
      end
    
      def global(name)
        return @library.globals(true)[name.to_sym]
      end
      
      # Numeric Operations
      
      def neg(v)
        @builder.neg(convert(v))
      end
    
      def inc(v, a=1)
        val = @builder.load(v)
        @builder.store(add(val, a), v)
      end
    
      def dec(v, a=1)
        val = @builder.load(v)
        @builder.store(sub(val, a), v)
      end
    
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
      
      def rem(v1, v2, signed=true)
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
    
      def shl(v1, v2)
        @builder.shl(convert(v1), convert(v2, v1.type))
      end
      
      def ashr(v1, v2)
        @builder.ashr(convert(v1), convert(v2, v1.type))
      end
      
      def lshr(v1, v2)
        @builder.lshr(convert(v1), convert(v2, v1.type))
      end
      
      # Casts
      
      def bitcast(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to bitcast must be of LLVM::Type. #{type_name(type)} given."
        end
        @builder.bit_cast(convert(v), type)
      end
      
      def trunc(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to bitcast must be of LLVM::Type. #{type_name(type)} given."
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
      
      def cast(v, type)
        type = LLVM::Type(type)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "Type passed to cast must be of LLVM::Type. #{type_name(type)} given."
        end
        val = convert(v)
        case v.type.kind
        when :integer
          @builder.int_cast(val, type)
        when :float, :double, :x86_fp80, :fp128, :ppc_fp128
          @builder.fp_cast(val, type)
        when :pointer
          @builder.pointer_cast(val, type)
        else
          raise ArgumentError, "Value passed to cast is not Numeric or Pointer."
        end
      end
      
      # Pointer Operations
      
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
      
      def free(ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The free function can only free pointers. #{type_name(ptr)} given."
        end
        @builder.free(ptr)
      end
    
      def load(ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The load function only accepts pointers. #{type_name(ptr)} given."
        end
        @builder.load(ptr)
      end
    
      def store(v, ptr)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The store function can only store values in pointers. #{type_name(ptr)} given."
        end
        @builder.store(convert(v, ptr.type.element_type), ptr)
      end
      
      # Collection Control
    
      def gep(ptr, *indices)
        unless ptr.kind_of?(LLVM::Value) && ptr.type.kind == :pointer
          raise ArgumentError, "The gep function can only index pointers. #{type_name(ptr)} given."
        end
        type = ptr.type.element_type
        type = type.element_type while type.kind == :pointer
        indices = indices.flatten.map do |idx|
          if idx.class.name == "Symbol" || idx.class.name == "String"
            index = Runtime.elements(type)[idx.to_sym]
            if index.nil?
              raise ArgumentError, "Unrecognized #{type.name+" "}element, '#{idx.to_s}', passed to gep."
            end
            index.map!{|i| convert(i)}
          else
            index = convert(idx)
          end
          index
        end
        @builder.gep(ptr, indices.flatten)
      end
    
      def gev(obj, *indices)
        @builder.load(gep(obj, *indices))
      end
    
      def sep(obj, *args)
        val = args.pop
        ptr = gep(obj, *args)
        @builder.store(convert(val, ptr.type.element_type), ptr)
      end
      
      def insert(collection, element, index)
        val = convert(collection)
        if value.type.kind == :vector
          @builder.insert_element(collection, convert(element, val.type.element_type), convert(index))
        else
          @builder.insert_value(collection, convert(element, val.type.element_type), convert(index))
        end
      end
      
      def extract(collection, index)
        val = convert(collection)
        if value.type.kind == :vector
          @builder.extract_element(collection, convert(index))
        else
          @builder.extract_value(collection, convert(index))
        end
      end
      
      # Boolean Operations
      
      def invert(v)
        @builder.not(convert(v))
      end
      
      def is_null(v)
        unless v.kind_of?(LLVM::Value)
          raise ArgumentError, "Value passed to is_null must be of LLVM::Value. #{type_name(v)} given."
        end
        @builder.is_null(v)
      end
      
      def is_not_null(v)
        unless v.kind_of?(LLVM::Value)
          raise ArgumentError, "Value passed to is_not_null must be of LLVM::Value. #{type_name(v)} given."
        end
        @builder.is_not_null(v)
      end
      
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
    
      # Flow Control
    
      def block(name="block", &proc)
        gen = self.class.new(@module, @function, @function.add_block(name))
        gen.instance_eval(&proc)
        return gen
      end
    
      def cond(cond, crt=nil, wrg=nil, exit=nil, &proc)
        exit_provided = exit ? true : false
        unless crt.kind_of?(self.class)
          gen = self.class.new(@library, @module, @function, @function.add_block("then"))
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
    
      def lp(vars=nil, cmp=nil, inc=nil, exit=nil, &proc)
        ptrs = []
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
          gen.instance_variable_set(:@loop_block, incblk)
          vals = ptrs[0, proc.arity >= 0 ? proc.arity : 0].map{ |p| gen.load(p) }
          gen.instance_exec(*vals, &proc)
          gen.br(inc ? incblk : loopblk)
          gen.finish
        end
        if cmp
          gen = self.class.new(@library, @module, @function, loopblk)
          vals = ptrs[0, cmp.arity >= 0 ? cmp.arity : 0].map{ |p| gen.load(p) }
          cond = gen.instance_exec(*vals, &cmp)
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
        @builder.position_at_end(exit)
        @basic_block = exit
        return ptrs.length == 1 ? ptrs.first : ptrs
      end
    
      def br(block)
        return if @finished
        @builder.br(block)
        self.finish
      end
    
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
    
      def ret_block
        return @function.return_block
      end
    
      def finished?
        return @finished
      end
    
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
            return (type || FLOAT).from_f(v)
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
    
      def respond_to?(sym, *args)
        return true if @library.macros(true).include?(sym)
        return true if @library.functions(true).include?(sym)
        return true if @library.globals(true).include?(sym)
        super(sym, *args)
      end   
    end
  end
end