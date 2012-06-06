module LLVM
  module Script
    # A non-executable container of functions, macros, and globals.
    class Library < ScriptObject
      
      # The name of this library
      attr_reader :name
      
      # When to prefix globals with the name of the library.
      attr_reader :prefix
      
      # The LLVM::Module the library represents.
      attr_reader :module
      
      # A Uuid placed in front of global string names in LLVM IR to prevent them from conflicting 
      # with other globals. It is chopped down to 5 characters to make the name somewhat readable 
      # (thought not extremely unique).
      @@str_id = nil
      
      @@libraries = {}      # @private
      @@last_library = nil  # @private
      
      # Retrieves a hash of all libraries (not including subclasses) that have been created.
      # @return [Hash<Symbol, LLVM::Script::Library>] An hash where each symbol is the name of the 
      #   library it points to.
      def self.collection
        return @@libraries
      end
      
      # Retrieves the last created library.
      # @return [LLVM::Script::Library] The last created library.
      def self.last
        return @@last_library
      end
      
      # Looks for the specified library.
      # @param [String, Symbol] name The name of the library to look for. If no name is given, 
      #   returns the last created library.
      # @return [LLVM::Script::Library] The found library.
      def self.lookup(name="")
        libs = self.collection
        if name.empty?
          return self.last
        elsif libs.include?(name.to_sym)
          return libs[name.to_sym]
        else
          raise ArgumentError, "#{self.nam}, #{name.to_s}, does not exist."
        end
      end
      
      # Creates a new library.
      # @param [String] name An optional name for the library. If you do not give one a unique id 
      #   will be generated using #make_uuid.
      # @param [Hash] opts Options for the new library.
      # @option opts [:all, :smart, :none] :prefix (:smart) When to prefix globals with the name of the library.
      #   :smart prefixes the functions in the LLVM IR but not in ruby-llvm-script. :all does both, :none does
      #   neither.
      # @option opts [:public, :private] :visibility (:public) The default visibility of globals in the library.
      # @param [Proc] block A block with the insides of the library.
      # @return [LLVM::Script::Library] The new library.
      def initialize(name="", opts={}, &block)
        @@str_id ||= make_uuid[0, 5]
        @prefix = opts[:prefix] == :none || opts[:prefix] == :all ? opts[:prefix] : :smart
        @visibility = opts[:visibility] == :private ? :private : :public
        @name = name.empty? ? make_uuid[0, 10] : name
        @module = LLVM::Module.new(name)
        @strings = {}
        @globals = {}
        @functions = {}
        @macros = {}
        @elements = {}
        if self.class == Library
          @@last_libary = self
          @@libraries[@name.to_sym] = self
        end
        build(&block) if ::Kernel.block_given?
      end
      
      # @private
      def to_ptr
        @module.to_ptr
      end
      
      # Prints the library's LLVM IR to $stdout.
      def dump
        @module.dump
      end
       
      # Builds the library, instance evaluating block.
      # @param [Proc] block The block to evaluate.
      def build(&block)
        self.instance_eval(&block)
      end
      
      # Imports the given library, adding all of its functions, macros, and globals to the caller.
      # If an imported function, macro, or global already exists, one of the following will happen:
      # Macros::  The macro will be overwritten, and from then on, the macro will execute as declared in 
      #           the imported library. This will NOT cause any unusual behavior.
      # Functions/Globals:: First, if the the object's name already exists in the library, it tries to rename
      #                     it to add the library's prefix (if prefix is :smart). If a object with that name
      #                     already exists, it will print a warning and the version in the caller will take 
      #                     precedence in ruby-llvm-script. However, what the linker will do depends on how 
      #                     the object was declared (ex. if a function's linkage is :weak, it will be overriden). 
      #                     If the linker is unable to resolve the conflict, it will error. *Advice:* Try to 
      #                     avoid function and global conflicts unless you know what you are doing.
      # @param [String, Symbol, LLVM::Script::Library] library The name of the library to import or the 
      #   library itself.
      # @return [LLVM::Script::Library] The imported library.
      # @raise [RuntimeError] Raised if the LLVM Linker fails.
      def import(library)
        if library.is_a?(String) || library.is_a?(Symbol)
          if @@libraries.has_key?(library.to_sym)
            library = @@libraries[library.to_sym]
          else
            raise ArgumentError, "Library, #{library.to_s}, does not exist."
          end
        elsif !library.kind_of?(Library)
          raise ArgumentError, "Can only import libraries. #{library.class.name} given."
        end
        @macros[:public] ||= {}
        @macros[:public].merge!(library.macros) 
        library.functions.each do |key, func|
          name = func.name
          key = functions.has_key?(key) ? name : key
          if functions.has_key?(name.to_sym)
            warn("Imported function, #{func.name}, already exists.")
          else
            args = func.varargs? ? func.arg_types + [VARARGS] : func.arg_types
            fun = Function.new(self, @module, name.to_s, args, func.return_type)
            fun.linkage = :external
            @functions[:public] ||= {}
            @functions[:public][key.to_sym] = fun
          end
        end
        library.globals.each do |key, glob|
          name = glob.name
          key = globals.has_key?(key) ? name : key
          if globals.has_key?(name.to_sym)
            warn("Imported global, #{key.to_s}, already exists.")
          else
            glb = @module.globals.add(glob.type, name.to_s)
            glb.global_constant = glob.global_constant?
            glb.linkage = :external
            @globals[:public] ||= {}
            @globals[:public][key.to_sym] = glb
          end
        end
        library.strings.each do |str, glob|
          if @strings.has_key?(str)
            @strings[str].linkage = :external
            @strings[str].initializer = nil
          else
            glb = @module.globals.add(glob.type, glob.name)
            glb.linkage = :external
            glb.global_constant = 1
            @strings[str] = glb
          end
        end
        err = @module.link(library.module, :linker_destroy_source)
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
      #   library do
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
      # @param [List<LLVM::Script::Function>] functions A list of functions to change to the new visibility.
      # @param [Proc] block A block to execute in the new visibility.
      def visibility(new_visibility=nil, *functions, &block)
        return @visiblity if new_visibility.nil?
        new_visibility = new_visibility == :private ? :private : :public
        @visibility = new_visibility unless ::Kernel.block_given? || functions.length > 0
        if ::Kernel.block_given?
          state = @visibility
          @visibility = new_visibility
          self.instance_eval(&proc)
          @visibility = state
        end
        if functions.length > 0
          @functions[new_visibility] ||= {}
          functions.each do |fname|
            @functions[new_visibility][fname.to_sym] = @functions[@visibility].delete(fname.to_sym)
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
        return (collection[:public] || {}) unless include_private
        return (collection[:public] || {}).merge(collection[:private] || {})
      end
      private :values
      
      # A hash of strings in the library.
      # @return [Hash{String, LLVM::GlobalValue}] Hash of string values pointing to their LLVM equivalants.
      def strings
        return @strings
      end
      
      # Creates a new function.
      # @param [String, Symbol] name The name of the function.
      # @param [Array<LLVM::Type>] args An array containing the types of the args in the function.
      #   See LLVM::Script::Types for a list of some of the more commonly used types.
      # @param [LLVM::Type] ret The type of value this function returns.
      # @param [Proc] block The insides of the function.
      # @return [LLVM::Script::Function] The new function.
      def function(name, args=[], ret=Types::VOID, &block)
        fullname = "#{@name}_#{name.to_s}"
        fun = Function.new(self, @module, @prefix == :none ? name.to_s : fullname, args, ret)
        if @visiblity == :private
          fun.linkage = :internal
        end
        @functions[@visibility] ||= {}
        @functions[@visibility][(@prefix == :all ? fullname : name).to_sym] = fun
        fun.build(&block)
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
      def extern(name, args=[], ret=VOID, attributes=[])
        fun = Function.new(self, @module, name.to_s, args, ret)
        fun.linkage = :external
        for atr in attributes
          fun.add_attribute(atr)
        end
        @functions[:public] ||= {}
        @functions[:public][name.to_sym] = fun
      end
      
      # Creates a new macro.
      # @param [String, Symbol] name The name of the macro.
      # @param [Proc] proc The insides of the macro, executed when the macro is called.
      # @return [Proc] The proc passed to the function.
      def macro(name, &proc)
        fullname = "#{@name}_#{name.to_s}"
        @macros[@visibility] ||= {}
        @macros[@visibility][(@prefix == :all ? fullname : name).to_sym] = proc
      end
      
      # Creates a new global value.
      # @param [String, Symbol] name The name of the global.
      # @param [LLVM::Value, LLVM::Type] info If an LLVM::Value, the default value of the global. 
      #   Otherwise, it is the type of the external global.
      # @return [LLVM::GlobalValue] The new global.
      def global(name, info)
        if info.kind_of?(LLVM::Type)
          glob = @module.globals.add(info, name.to_s)
          glob.linkage = :external
          @globals[:public] ||= {}
          @globals[:public][name.to_sym] = glob
        else
          fullname = "#{@name}_#{name.to_s}"
          glob = @module.globals.add(value.type, @prefix == :none ? name.to_s : fullname)
          glob.initializer = value
          if @visiblity == :private
            glob.linkage = :private
          end
          @globals[@visibility] ||= {}
          @globals[@visibility][(@prefix == :all ? fullname : name).to_sym] = glob
        end
      end
      
      # Creates a new global constant.
      # @param [String, Symbol] name The name of the constant.
      # @param [LLVM::Value] value The value of the constant.
      # @return [LLVM::GlobalValue] The new constant.
      def constant(name, value)
        glob = global(name, value)
        glob.global_constant = 1
        return glob
      end
      
      # Converts a ruby string into a LLVM global string (these strings are constant).
      # @param [String] value The contents of the new string.
      # @param [String, Symbol] name The optional name of the string.
      # @return [LLVM::GlobalValue] The new string.
      def string(value, name="")
        if @strings.has_key?(value)
          return @strings[value]
        else
          array = LLVM::ConstantArray.string(value)
          glob = @module.globals.add(array.type, "#{@@str_id}-#{value}")
          glob.initializer = array
          glob.global_constant = 1
          @strings[value] = glob
        end
      end
    end
  end
end