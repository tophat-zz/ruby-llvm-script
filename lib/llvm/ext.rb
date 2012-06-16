module LLVM
  class ConstantStruct 
    def self.typed_const(type, size_or_values, &block)
      vals = LLVM::Support.allocate_pointers(size_or_values, &block)
      from_ptr(C.const_named_struct(type, vals, vals.size / vals.type_size))
    end
  end
  
  class Function < GlobalValue 
    class BasicBlockCollection   
      def insert(block_after, name="") 
        BasicBlock.from_ptr(C.insert_basic_block(block_after, name))
      end
    end
  end
  
  class BasicBlock < Value 
    def empty?
      return instructions.first.nil?
    end
       
    def move_before(block)
      C.move_basic_block_before(self, block)
    end
     
    def move_after(block)
      C.move_basic_block_after(self, block)
    end
     
    def dispose
      C.delete_basic_block(self)
    end  
  end
  
  def self.Type(ty)
    case ty
    when LLVM::Type 
      return ty
    when LLVM::Value, Class
      return ty.type
    else 
      return nil
    end
  end
end