module LLVM
  module Script
    # A container of other namespaces.
    class Namespace < ScriptObject
      
      # The name of this namespace
      attr_reader :name
      
      # The namespace in which this namespace resides.
      attr_reader :parent
      
      # The name of this namespace and its parent's address joined together with a ".".
      # Used in libraries to prefix functions and globals in LLVM IR.
      attr_reader :address
      
      # Creates a new namespace.
      # @param [Symbol, String] name A name for the namespace.
      # @param [LLVM::Script::Namespace] parent An optional namespace in which this namespace resides.
      # @param [Proc] block An optional block to build the new namespace with.
      def initialize(name, parent=nil, &block)
        @name = name.to_s
        @collection = {}
        @last_space = nil
        @parent = parent
        @address = parent.nil? ? @name : "#{parent.address}.#{@name.gsub(" ", "")}"
        @parent.add(self) if @parent
        build(&block) if ::Kernel.block_given?
      end
      
      # Instance evaluates the given block.
      # @param [Proc] block The block to evaluate.
      def build(&block)
        self.instance_eval(&block)
      end
      
      # Retrieves an hash of the namespaces contained in this namespace.
      # @return [Hash<Symbol, LLVM::Script::Namespace>] A hash where a symbol name corresponds to a namespace.
      def collection
        return @collection
      end
      
      # Retrieves the last namespace created in this namespace.
      # @return [LLVM::Script::Namespace] The last created namespace.
      def last
        return @last_space
      end
      
      # Adds the given namespace into this namespace.
      # @param [LLVM::Script::Namespace] space The namespace to add.
      def add(space)
        @collection[space.name.to_sym] = space
        @last_space = space
      end
      
      # Looks for the specified namespace with the given name in this namespace and its parents.
      # @param [String, Symbol] name The name of the namespace to look for. If no name is given, 
      #   returns {#last}.
      # @return [LLVM::Script::Namespace] The found namespace or nil if none was found.
      def lookup(name="")
        if name.to_s.empty?
          return self.last
        elsif @collection.include?(name.to_sym)
          return @collection[name.to_sym]
        elsif @parent
          return @parent.lookup(name)
        end
        return nil
      end
      
      # Checks if a namespace with the given name is in this namespace or its parent's.
      # @param [String, Symbol] name The name of the namespace to look for.
      # @return [Boolean] The resulting true/false value.
      def include?(name)
        return collection.include?(name.to_sym) || (@parent && @parent.include?(name))
      end
      
      # @!macro [new] factory
      #   Creates a new $0 with the given name in this namespace.
      #   @param [Symbol, String] $1 A name for the $0.
      #   @param [Proc] block An optional block instance to build the new $0 with.
      def __factory__(klass, name, &block)
        sym = name.to_sym
        if @collection.include?(sym)
          space = @collection[sym]
          space.instance_eval(&block) if ::Kernel.block_given?
        else
          space = klass.new(name, self, &block)
          @collection[sym] = space
          @last_space = space
        end
        return space
      end
      private :__factory__
      
      # @macro factory
      # @return [LLVM::Script::Namespace] The new namespace.
      def namespace(name, &block)
        __factory__(Namespace, name, &block)
      end
      
      # @macro factory
      # @return [LLVM::Script::Library] The new library.
      def library(name, &block)
        __factory__(Library, name, &block)
      end
      
      # @macro factory
      # @return [LLVM::Script::Program] The new program.
      def program(name, &block)
        __factory__(Program, name, &block)
      end
      
      # If a method is unkown, tries to get a namespace in this namespaces collection with 
      # the method symbol.
      # @example
      #   ex = namespace("ex")
      #   ex.library "myamazinglib"
      #   ex.myamazinglib # => <LLVM::Script::Library>
      #
      #   # Which allows one to do things like this.
      #   ex.myamazinglib.function :awesomeness do
      #     # function contents
      #   end
      def method_missing(meth, *args, &block)
        return @collection[meth] || super(meth, *args, &block)
      end
      
      # If a method is unkown, checks if their is a namespace with the method symbol.
      def respond_to?(meth, *args, &block)
        return @collection.include?(meth) || super(meth, *args, &block)
      end
    end
    
    # A {LLVM::Script::Namespace} that is used by Kernel methods and is the default namespace for newly 
    # created libraries.
    DEFAULT_SPACE = Namespace.new("rls")
  end
end