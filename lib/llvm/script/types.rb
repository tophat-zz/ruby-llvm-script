module LLVM
  module Script
    # Short-cuts to some basic LLVM types with more descriptive names.
    module Types
      
      # When used as a function argument type, this represents variable arguments 
      # (i.e. the LLVM equivlant of *args in Ruby)
      VARARGS     = :varargs
    
      INT         = LLVM::Int
      BOOL        = LLVM::Int1
      CHAR        = LLVM::Int8
      VOID        = LLVM::Type.void
      SHORT       = LLVM::Int16
      LONG        = LLVM::Int32
      BIG         = LLVM::Int64
      FLOAT       = LLVM::Float
      DOUBLE      = LLVM::Double
      
      INTPTR      = LLVM::Pointer(INT)
      BOOLPTR     = LLVM::Pointer(BOOL)
      CHARPTR     = LLVM::Pointer(CHAR)
      VOIDPTR     = LLVM::Pointer(LLVM::Int8)
      SHORTPTR    = LLVM::Pointer(SHORT)
      LONGPTR     = LLVM::Pointer(LONG)
      BIGPTR      = LLVM::Pointer(BIG)
      FLOATPTR    = LLVM::Pointer(FLOAT)
      DOUBLEPTR   = LLVM::Pointer(DOUBLE)
      
      CHARPTRPTR  = CHARPTR.pointer
      VOIDPTRPTR  = VOIDPTR.pointer
    
    end
  end
end
      
      
    