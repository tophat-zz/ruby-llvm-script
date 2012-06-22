require 'script_test'

class TestStruct < MiniTest::Unit::TestCase
  
  def setup
    @struct = LLVM::Script::Struct.new
  end
  
  def check_lookup(methname)
    basic = LLVM::Script::Struct.new(LLVM::Int)
    assert_raises(RuntimeError) { basic.__send__(methname, :unimportant) }
    struct = LLVM::Script::Struct.new "testruct",
     :recur => LLVM::Script::Struct.new(:deep => LLVM::Int)
    return struct
  end
  
  def test_initialize
    arged = LLVM::Script::Struct.new(LLVM::Int, LLVM::Double)
    struct = LLVM::Script::Struct.new("teststruct", [LLVM::Int])
    assert_equal "teststruct", LLVM::Script::Struct.new("teststruct").name
    assert_equal [LLVM::Int.type, LLVM::Double.type], arged.elements
    assert_equal [LLVM::Int.type], struct.elements
    assert_equal "teststruct", struct.name
  end
  
  def test_elements
    @struct.elements = [LLVM::Int, LLVM::Double]
    assert_equal [LLVM::Int.type, LLVM::Double.type], @struct.elements
    @struct.elements = nil
    assert_equal [], @struct.elements
  end
  
  def test_index
    struct = check_lookup(:index)
    assert_raises(ArgumentError){ struct.index(:nonexistant) }
    assert_equal [0, 0], struct.index(:deep)
    assert_equal [0], struct.index(:recur)
  end
  
  def test_type
    struct = check_lookup(:type)
    assert_raises(ArgumentError){ struct.type(:nonexistant) }
    assert_equal LLVM::Int.type, struct.type(:deep)
    assert_equal :struct, struct.type(:recur).kind
  end
  
  def test_include
    struct = check_lookup(:include?)
    refute struct.include?(:nonexistant)
    assert struct.include?(:recur)
    assert struct.include?(:deep)
  end
  
  def test_align
    assert_instance_of LLVM::Int64, @struct.align
  end
  
  def test_pointer
    ptr = @struct.pointer
    assert_instance_of LLVM::Type, ptr
    assert_equal :pointer, ptr.kind
    assert_equal :struct, ptr.element_type.kind
  end
  
  def test_null
    null = @struct.null
    assert_instance_of LLVM::ConstantExpr, null
    assert_equal :struct, null.type.kind
  end
  
  def test_null_pointer
    ptr = @struct.null_pointer
    assert_instance_of LLVM::ConstantExpr, ptr
    assert_equal :struct, ptr.type.kind
  end
end