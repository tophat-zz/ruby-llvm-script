require 'script_test'

class TestCore < MiniTest::Unit::TestCase
  def test_convert
    assert_instance_of LLVM::Int1,            LLVM::Script::Convert(true)
    assert_instance_of LLVM::Int1,            LLVM::Script::Convert(false)
    assert_instance_of LLVM::Float,           LLVM::Script::Convert(2.5)
    assert_instance_of LLVM::Int,             LLVM::Script::Convert(512)
    assert_instance_of LLVM::ConstantArray,   LLVM::Script::Convert("Test")
    assert_instance_of LLVM::ConstantArray,   LLVM::Script::Convert([12, 4, 9])
    assert_instance_of LLVM::ConstantVector,  LLVM::Script::Convert([12, 4, 9], :vector)
    null_ptr = LLVM::Script::Types::CHARPTR.null_pointer
    assert_equal null_ptr, LLVM::Script::Convert(nil, LLVM::Script::Types::CHARPTR)
    assert_raises(ArgumentError) { LLVM::Script::Convert(Object.new) }
  end
  
  def test_decimal
    assert LLVM::Script::Decimal(:float)
    assert LLVM::Script::Decimal(:decimal)
    refute LLVM::Script::Decimal(:integer)
  end
  
  def test_typename
    assert_equal "LLVM::Int32",                 LLVM::Script::Typename(LLVM::Int32.type)
    assert_equal "LLVM::Int8 pointer",          LLVM::Script::Typename(LLVM::Script::Types::CHARPTR)
    assert_equal "LLVM::Int8 pointer pointer",  LLVM::Script::Typename(LLVM::Script::Types::CHARPTRPTR)
    assert_equal "Void",                        LLVM::Script::Typename(LLVM::Script::Types::VOID)
    assert_equal "Numeric",                     LLVM::Script::Typename(:numeric)
  end
  
  def test_validate
    assert LLVM::Script::Validate(LLVM::Int32.type,       :type)
    assert LLVM::Script::Validate(LLVM::Int32.from_i(8),  :value)
    assert_raises(ArgumentError) { LLVM::Script::Validate("non-type",   :type) }
    assert_raises(ArgumentError) { LLVM::Script::Validate("non-value",  :value) }
    assert_raises(ArgumentError) { LLVM::Script::Validate("bad kind",   :nonexistant) }
  end
end