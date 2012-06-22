module LLVM
  module Script
    # A LLVM::StructType with named elements.
    class Struct
    
      # @private
      @@structs = {}
    
      # The name of the struct.
      attr_reader :name
      
      # Finds the LLVM::Script::Struct corresponding to the given LLVM::StructType.
      # @param [LLVM::StructType] type The LLVM::StructType to map.
      # @return [LLVM::Script::Struct] The resulting LLVM::Script::Struct.
      def self.[](type)
        return @@structs[type]
      end
    
      # Defines a new struct type. If a element hash is passed to Struct, there is no garentee
      # It will retains its element order on Ruby 1.8.x. If you need this functionality, pass
      # an OrderedHash or Dictionary created with a gem like #{http://rubyworks.github.com/hashery/ Hashery}.
      # @overload initialize
      #   Defines a new opaque struct, useful for the forward-declaration of structs. 
      # @overload initialize(name)
      #   Defines a new opaque struct with the given name, allowing it to be used as an 
      #   externally defined struct.
      #   @param [String, Symbol] name The name of the struct. 
      # @overload initialize(elements)
      #   Defines a new struct type with the given elements.
      #   @param [Hash<String/Symbol, LLVM::Type>, Array<LLVM::Type>] elements A hash of 
      #     element names corresponding to that element's type or an array of element types.
      # @overload initialize(*elements)
      #   Defines a new struct type with the given elements.
      #   @param [List<LLVM::Type>] elements A list of the struct's element types.
      # @overload initialize(name, elements)
      #   Defines a new struct type with the given name and elements.
      #   @param [String, Symbol] name The name of the struct.
      #   @param [Hash<String/Symbol, LLVM::Type>, Array<LLVM::Type>] elements A hash of 
      #     element names corresponding to that element's type or an array of element types.
      # @overload initialize(name, *elements)
      #   Defines a new struct type with the given name and elements.
      #   @param [String, Symbol] name The name of the struct.
      #   @param [List<LLVM::Type>] elements A list of the struct's element types.
      # @return [LLVM::Script::Struct] The newly defined struct.
      def initialize(*args)
        return @raw = LLVM::Type.struct([], false) if args.empty?
        case args.first
        when String, Symbol
          @name = args.shift.to_s
          @raw = LLVM::Struct(@name)
          self.elements = args[0].is_a?(Hash) || args[0].is_a?(Array) ? args[0] : args
        when Hash, Array
          @raw = LLVM::Type.struct([], false)
          self.elements = args.first
        else
          @raw = LLVM::Type.struct([], false)
          self.elements = args
        end
        @@structs[@raw] = self
      end
    
      # @private
      def to_ptr
        @raw.to_ptr
      end
      
      # An array or hash of the elments in the struct.
      # @return [Hash<Symbol, LLVM::Type>] A hash of element names corresponding to 
      #   that element's type or an array of elment types.
      def elements
        return @types.dup
      end
      
      # Sets the element hash of the struct.
      # @param [Hash<String/Symbol, LLVM::Type>, Array<LLVM::Type>, nil] elements A hash of element names 
      #   corresponding to that element's type or an array of element types. If nil, the struct is emptied.
      def elements=(elements)
        case elements
        when Hash
          @names = elements.keys
          @types = elements.class.new
          elements.each { |name, type| @types[name.to_sym] = LLVM::Script::Validate(type, :type) }
          @raw.element_types = @types.values
        when Array
          @names = []
          @types = elements.flatten.collect{ |type | LLVM::Script::Validate(type, :type) }
          @raw.element_types = @types
        else
          @names = []
          @types = []
          @raw.element_types = []
        end
      end
      
      # Gets the index of the given element in the struct. If the element does not exist 
      # in the struct, tt will search through all structs within itself for it. If it can not
      # be found a ArgumentError will be raised.
      # @param [Symbol, String] element The name of the element to retrieve the index of.
      # @return [Array<Integer>] The indices of the given element when using a function like gep.
      # @see LLVM::Script::Generator#gep
      def index(element)
        raise RuntimeError, "Cannot call index on a Struct without element names." if @names.empty?
        return [@names.index(element.to_sym)] if @names.include?(element.to_sym)
        @types.each do |name, type|
          next unless type.is_a?(LLVM::Script::Struct) && type.include?(element)
          return [@names.index(name), type.index(element)].flatten
        end
        raise ArgumentError, "Unkown element, #{element.to_s}."
      end
      
      # Gets the type of the given element in the struct. If the element does not exist 
      # in the struct, tt will search through all structs within itself for it. If it can not
      # be found a ArgumentError will be raised.
      # @param [Symbol, String] element The name of the element to retrieve the type of.
      # @return [LLVM::Type] The type of the element with the given name.
      def type(element)
        raise RuntimeError, "Cannot call type on a Struct without element names." if @names.empty?
        return @types[element.to_sym] if @names.include?(element)
        @types.each_value do |type|
          next unless type.is_a?(LLVM::Script::Struct) && type.include?(element)
          return type.type(element)
        end
        raise ArgumentError, "Unkown element, #{element.to_s}."
      end
      
      # Checks whether the element with the given name exists in the struct or any sub-struct.
      # @param [Symbol, String] element The name of the element to retrieve to look for.
      # @return [Boolean] The resulting true/false value.
      def include?(element)
        raise RuntimeError, "Cannot call include? on a Struct without element names." if @names.empty?
        return true if @names.include?(element)
        @types.each_value do |type|
          return true if type.is_a?(LLVM::Script::Struct) && type.include?(element)
        end
        return false
      end
      
      # The alignment of the type in memory.
      # @return [LLVM::Int64] The alignment of the struct.
      def align 
        return @raw.align 
      end
      
      # The symbol kind of a struct type (:struct).
      # @return [Symbol] The struct kind.
      def kind 
        return @raw.kind 
      end
      
      # The struct wrapped in a pointer.
      # @param [Integer] address_space The {http://en.wikipedia.org/wiki/Address_space address space} 
      #   of the pointer.
      # @return [LLVM::Type] A LLVM::Type representing a pointer to the struct.
      def pointer(address_space = 0)
        return @raw.pointer(address_space)
      end
      
      # A value containing the null of this struct.
      # @return [LLVM::ConstantExpr] The null value.
      def null 
        return @raw.null 
      end
      
      # A pointer of this type pointing to NULL.
      # @return [LLVM::ConstantExpr] The pointer.
      def null_pointer 
        return @raw.null_pointer
      end
    end
  end
end