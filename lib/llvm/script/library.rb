module LLVM
  module Script
    # A namespace containing macros, functions, and globals.
    class Library < Namespace 
      # Creates a new library.
      # @param [Symbol, String] name A name for the library.
      # @param [LLVM::Script::Namespace] space The namespace in which this library resides.
      # @param [Proc] block A block with the insides of the library.
      # @return [LLVM::Script::Library] The new library.
      def initialize(name, space=DEFAULT_SPACE, &block)
        @visibility = :public
        @module = LLVM::Module.new(name)
        @globals = {:public=>{}, :private=>{}}
        @functions = {:public=>{}, :private=>{}}
        @macros = {:public=>{}, :private=>{}}
        super(name, space, &block)
      end
      
      # @private
      def to_ptr
        @module.to_ptr
      end
      
      # Prints the library's LLVM IR to $stdout.
      def dump
        @module.dump
      end
      
      # Imports the given library, adding all of its public functions, macros, and globals to the caller.
      # If any object in the caller has the same name as one of the imported objects, one of the following
      # will happen depending on what level the conflict occurred:
      # Ruby::      The object will be overwritten, and from then on, the object will execute as declared in the 
      #             imported library.
      # LLVM IR::   A warning will be printed and if the linker is unable to resolve the conflict 
      #             a RuntimeError will be raised.
      # @param [String, Symbol, LLVM::Script::Library] library The name of the library to import or the 
      #   library itself.
      # @return [LLVM::Script::Library] The imported library.
      # @raise [RuntimeError] Raised if the LLVM Linker fails.
      def import(library)
        if library.is_a?(String) || library.is_a?(Symbol)
          unless self.include?(library)
            raise ArgumentError, "Library, #{library.to_s}, does not exist."
          end
          library = self.lookup(library)
        elsif library.class != Library
          raise ArgumentError, "Can only import libraries. #{library.class.name} given."
        end
        @macros[:public].merge!(library.macros)
        library.functions.each do |name, func|
          if @module.functions.named(func.name)
            warn("Imported function's (#{name.to_s}) address, #{func.name}, already exists.")
          end
          args = func.varargs? ? func.arg_types + [Types::VARARGS] : func.arg_types
          fun = Function.new(self, @module, func.name, args, func.return_type)
          @functions[:public][name.to_sym] = fun
        end
        library.globals.each do |name, info|
          if @module.globals.named(info.name)
            warn("Imported global's (#{name.to_s}) address, #{info.name}, already exists.")
          end
          glob = @module.globals.add(info.type, info.name)
          glob.global_constant = info.global_constant?
          @globals[:public][name.to_sym] = glob
        end
        err = @module.link(library, :linker_destroy_source)
        raise RuntimeError, "Failed to link library, #{library.name.to_s}, to #{name}." if err
        return library
      end
      
      # Shortcut to visibility with :public as the new visiblility. Equivalant to:
      #   visibility :public, *functions, &block
      # @param [List<LLVM::Script::Function>] functions A list of functions to change to private visibility.
      # @param [Proc] block A block to execute in private visibility.
      # @see LLVM::Script::Library#visibility
      def public(*functions, &block)
        visibility(:public, *functions, &block)
      end
      
      # Shortcut to visibility with :private as the new visiblility. Equivalant to:
      #   visibility :private, *functions, &block
      # @param [List<LLVM::Script::Function>] functions A list of functions to change to public visibility.
      # @param [Proc] block A block to execute in public visibility.
      # @see LLVM::Script::Library#visibility
      def private(*functions, &block)
        visibility(:private, *functions, &block)
      end
      
      # Visiblity control. 
      # If given no arguments, returns the current visibility.
      # If just given a new visibility, sets the visibility to it.
      # If given a block, evaluates it in the given visibility.
      # If given a set of functions, changes the visibility of those 
      # functions to the given visibility.
      # @example
      #   library "VisibilityExample" do
      #     visibility  # => :public
      #     function :somefunc do
      #       # function contents
      #     end
      #     functions   # => {:somefunc => <LLVM::Script::Function>}
      #
      #     visibility :private, :somefunc
      #     functions   # => {}
      #
      #     visibility :private do
      #       visibility  # => :private
      #       function :privatefunc do
      #         # function contents
      #       end
      #     end
      #     functions   # => {}
      #
      #     visibility  # => :public
      #     visibility :private
      #     visibility  # => :private
      #   end
      # @param [:public, :private, nil] new_visibility The new visibility.
      # @param [List<LLVM::Script::Function, LLVM::Value>] values A list of functions, macros, and/or globals 
      #   to change to the new visibility.
      # @param [Proc] block A block to execute in the new visibility.
      def visibility(new_visibility=nil, *values, &block)
        return @visibility if new_visibility.nil?
        new_visibility = new_visibility == :private ? :private : :public
        @visibility = new_visibility unless ::Kernel.block_given? || values.length > 0
        if ::Kernel.block_given?
          state = @visibility
          @visibility = new_visibility
          self.instance_eval(&block)
          @visibility = state
        end
        if values.length > 0
          linkage = (new_visibility == :private ? :private : :external)
          values.each do |name|
            name = name.to_sym
            if functions(true).include?(name)
              @functions[new_visibility][name] = @functions[@visibility].delete(name)
              @functions[new_visibility][name].linkage = linkage
            elsif macros(true).include?(name)
              @macros[new_visibility][name] = @macros[@visibility].delete(name)
            elsif globals(true).include?(name)
              @globals[new_visibility][name] = @globals[@visibility].delete(name)
              @globals[new_visibility][name].linkage = linkage
            else
              raise ArgumentError, "Unknown function, macro, and/or global, #{name.to_s}, passed to visibility."
            end
          end
        end
      end
      
      # An hash of functions in the library.
      # @param [Boolean] include_private Whether or not to include 
      #   functions whose visibility is private in the hash.
      # @return [Hash{Symbol, LLVM::Script::Function}] Hash of symbol names pointing to functions.
      def functions(include_private=false)
        values(@functions, include_private)
      end
      
      # An hash of macros in the library.
      # @param [Boolean] include_private Whether or not to include 
      #   macros whose visibility is private in the hash.
      # @return [Hash{Symbol, Proc}] Hash of symbol names pointing to procs (macros).
      def macros(include_private=false)
        values(@macros, include_private)
      end
      
      # An hash of globals in the library.
      # @param [Boolean] include_private Whether or not to include 
      #   macros whose visibility is private in the hash.
      # @return [Hash{Symbol, LLVM::GlobalValue}] Hash of symbol names pointing to globals.
      def globals(include_private=false)
        values(@globals, include_private)
      end
      
      # @private
      def values(collection, include_private=false)
        return (collection[:public]) unless include_private
        return (collection[:public]).merge(collection[:private])
      end
      private :values
      
      # Creates a new function.
      # @param [String, Symbol] name The name of the function.
      # @param [Array<LLVM::Type>] args An array containing the types of the args in the function.
      #   See LLVM::Script::Types for a list of some of the more commonly used types.
      # @param [LLVM::Type] ret The type of value this function returns.
      # @param [Proc] block The insides of the function.
      # @return [LLVM::Script::Function] The new function.
      def function(name, args=[], ret=Types::VOID, &block)
        fun = Function.new(self, @module, "#{@address}.#{name.to_s}", args, ret)
        fun.linkage = :private if @visibility == :private
        @functions[@visibility][name.to_sym] = fun
        fun.build(&block) if ::Kernel.block_given?
        return fun
      end
      
      # Declares an external function (usually one found in th C standard lib).
      # @param [String, Symbol] name The name of the function.
      # @param [Array<LLVM::Type>] args An array containing the types of the args in the function.
      #   See LLVM::Script::Types for a list of some of the more commonly used types.
      # @param [LLVM::Type] ret The type of value this function returns.
      # @param [Array<Symbol>] attributes An array of the attributes of this function.
      #   The current version of ruby-llvm (3.0.0) has no attributes, so ignore this.
      # @return [LLVM::Script::Function] The external function.
      def extern(name, args=[], ret=Types::VOID, attributes=[])
        fun = Function.new(self, @module, name.to_s, args, ret)
        # for atr in attributes
        #  fun.add_attribute(atr)
        # end
        @functions[:public][name.to_sym] = fun
      end
      
      # Creates a new macro.
      # @param [String, Symbol] name The name of the macro.
      # @param [Proc] proc The insides of the macro, executed when the macro is called.
      # @return [Proc] The proc passed to the function.
      def macro(name, &proc)
        @macros[@visibility] ||= {}
        @macros[@visibility][name.to_sym] = proc
      end
      
      # Creates a new global value.
      # @param [String, Symbol] name The name of the global.
      # @param [Object] info If an LLVM::Value or Ruby equivalent, the default value of the global. 
      #   Otherwise, it is the type of the external global.
      # @return [LLVM::GlobalValue] The new global.
      def global(name, info)
        if info.kind_of?(LLVM::Type) || info.is_a?(Class)
          glob = @module.globals.add(info, name.to_s)
          @globals[:public][name.to_sym] = glob
        else
          val = LLVM::Script::Convert(info)
          glob = @module.globals.add(val.type, "#{@address}.#{name.to_s}")
          glob.initializer = val
          glob.linkage = :private if @visibility == :private
          @globals[@visibility][name.to_sym] = glob
        end
      end
      
      # Creates a new global constant.
      # @param [String, Symbol] name The name of the constant.
      # @param [LLVM::Value, LLVM::Type] info If an LLVM::Value, the value of the constant. 
      #   Otherwise, it is the type of the external constant.
      # @return [LLVM::GlobalValue] The new constant.
      def constant(name, info)
        glob = global(name, info)
        glob.global_constant = 1
        return glob
      end
    end
  end
end