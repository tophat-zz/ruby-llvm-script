module LLVM
  module Script
    # Converts an object into a LLVM::Value. A hint can be specified to ensure that the value is 
    # of a given kind or type.
    #
    # <b>Conversion Table</b>
    # 
    #   Ruby      | LLVM                            | Possible Kinds        | Possible Types                            
    #   -------------------------------------------------------------------------------------------
    #   nil, 0    | null pointer                    | (none)                | A pointer type
    #   true      | i1 0                            | :numeric, :integer    | Int1                     
    #   false     | i1 1                            | :numeric, :integer    | Int1                                         
    #   Float     | Float or Double                 | :numeric, :decimal    | Float, Double  
    #   Numeric   | ConstantInt                     | :numeric, :integer    | Int1 to Int64                    
    #   String    | ConstantArray, i8 pointer       | :pointer, :array      | Int8 array or pointer                    
    #   Array     | ConstantArray, ConstantVector   | :array, :vector       | An array type                       
    #
    # @param [Object] val The object to convert into a LLVM::Value.
    # @param [Symbol, LLVM::Type] hint A symbolic kind or a LLVM::Type that signifies what kind 
    #   an object should be. If nil, the value will be converted based on its class.
    # @return [LLVM::Value] The newly converted LLVM::Value
    def self.Convert(val, hint=nil)
      type = LLVM::Type(hint)
      kind = hint if hint.is_a?(Symbol)
      kind = type.kind if type.kind_of?(LLVM::Type)
      klass = Types::DOUBLE if type == LLVM::Double.type || kind == :double
      klass = LLVM.const_get("Int#{type.width}".to_sym) if type.kind_of?(LLVM::IntType) 
      if val.kind_of?(LLVM::Value)
        if hint.nil? || val.type == type || (type.nil? && ((kind == :decimal && Decimal(val.type.kind)) ||
            (kind == :numeric && (val.type.kind == :integer || Decimal(val.type.kind))) || val.type.kind == kind))
          return val
        end
      elsif val.kind_of?(LLVM::Script::ScriptObject)
        return val
      elsif (val == 0 || val.nil?) && !type.nil? && kind == :pointer
        return type.null_pointer
      elsif val == true && (kind.nil? || kind == :numeric || kind == :integer)
        return (klass || Types::BOOL).from_i(1)
      elsif val == false && (kind.nil? || kind == :numeric || kind == :integer)
        return (klass || Types::BOOL).from_i(0)
      elsif Decimal(kind) || (val.kind_of?(::Float) && (kind.nil? || kind == :numeric))
        return (klass || Types::FLOAT).from_f(val.to_f)
      elsif kind == :integer || kind == :numeric || (kind.nil? && val.kind_of?(Numeric))
        return (klass || Types::INT).from_i(val.to_i)
      elsif val.kind_of?(String) && (kind.nil? || kind == :pointer || kind == :array)
        str = LLVM::ConstantArray.string(val.to_s)
        return kind == :pointer ? str.bitcast_to(Types::CHARPTR) : str
      elsif kind == :array || (kind.nil? && val.kind_of?(Array))
        type = !type.nil? ? type.element_type : Convert(val.to_a.first).type
        return LLVM::ConstantArray.const(type, val.to_a.map{|elm| Convert(elm, type)})
      elsif kind == :vector
        type = !type.nil? ? type.element_type : Convert(val.to_a.first).type
        return LLVM::ConstantVector.const(val.to_a.map{|elm| Convert(elm, type)})
      end
      if hint.nil?
        possibles = "LLVM::Value, Numeric, Array, String, or True/False/Nil"
        raise ArgumentError, "Cannot convert #{Typename(val)}, it is not of #{possibles}."
      else
        raise ArgumentError, "Cannot convert #{Typename(val)} into a #{Typename(hint)}."
      end
    end
    
    # Checks that the given kind is a float kind (:decimal, :float, :double, :x86_fp80, :fp128, or :ppc_fp128).
    # :decimal in ruby-llvm-script signifies any kind of float.
    # @param [Object] kind The kind to check.
    # @return [Boolean] The resulting true/false value.
    def self.Decimal(kind)
      case kind
      when :decimal, :float, :double, :x86_fp80, :fp128, :ppc_fp128
        return true
      end
      return false
    end
    
    # Validates that an object is of the given kind.
    # @param [Object] obj The object to validate. 
    # @param [:value, :type] kind The kind of object +obj+ should be. :value means an LLVM::Value, 
    #   :type means an LLVM::Type.
    # @return [LLVM::Value, LLVM::Type] The valid object.
    def self.Validate(obj, kind)
      case kind
      when :value
        unless obj.kind_of?(LLVM::Value)
          raise ArgumentError, "#{obj.class.name} is not a valid LLVM::Value."
        end
        return obj
      when :type
        type = LLVM::Type(obj)
        unless type.kind_of?(LLVM::Type)
          raise ArgumentError, "#{obj.class.name} is not a valid LLVM::Type."
        end
        return type
      else
        raise ArgumentError, "Kind passed to validate must be either :value or :type. #{kind.inspect} given."
      end
    end
  
    # Returns a human-readable description of the given object's type.
    # @param [Object] obj The object to inspect. 
    # @return [String] The resulting type-name.
    def self.Typename(obj)
      return obj.name if obj.kind_of?(Class)
      type = LLVM::Type(obj)
      if type.kind_of?(LLVM::Type)
        kind = type.kind
        if kind == :pointer
          kind = type.element_type.kind while kind == :pointer
          return "#{kind.to_s.capitalize} pointer"
        elsif kind == :integer
          return LLVM.const_get("Int#{type.width}".to_sym).name
        else
          return kind.to_s.capitalize
        end
      elsif obj.kind_of?(Symbol)
        return obj.to_s.capitalize
      else
        return obj.class.name
      end
    end
  end
end