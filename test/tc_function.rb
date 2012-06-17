require 'script_test'

class TestFunction < MiniTest::Unit::TestCase
  
  def make_function(args=[], ret=LLVM::Script::Types::VOID, &block)
    lib = LLVM::Script::Library.new("testlib")
    @fun = lib.function(:testfunc, args, ret, &block)
  end
  
  def test_initialize
    func = make_function [LLVM::Int, LLVM::Float, LLVM::Script::Types::VARARGS], LLVM::Int8
    assert_equal [LLVM::Int, LLVM::Float], func.arg_types
    assert_equal LLVM::Int8, func.return_type
    assert_equal "rls.testlib.testfunc", func.name
    assert func.varargs?
  end 
  
  def test_build
    testcase = self
    func = make_function
    refute_silent do 
      func.build { testcase.assert_instance_of LLVM::Script::Generator, self }
    end
    assert func.finished?
  end
  
  def test_args
    func = make_function
    assert_equal func.args, func.params
  end
  
  def test_bitcast
    func = make_function
    ntype = LLVM::Function([], LLVM::Int8, :varargs => true)
    assert_equal ntype, func.bitcast(ntype).type
  end
  
  def test_pointer
    func = make_function
    assert_equal LLVM::Pointer(func.type), func.pointer
  end
  
  def test_add_block
    func = make_function
    bb = func.add_block("testblock")
    assert_instance_of LLVM::BasicBlock, bb
    assert_equal "testblock", bb.name
  end
  
  def test_setup_return
    func = make_function [], LLVM::Int
    assert_nil func.return_val
    assert_nil func.return_block
    func.build{ ret 1 }
    func.setup_return
    assert_instance_of LLVM::Instruction, func.return_val
    assert_instance_of LLVM::BasicBlock, func.return_block
    assert_equal LLVM::Pointer(func.return_type), func.return_val.type
  end
  
  def test_setup_void_return
    func = make_function
    func.build{ ret }
    func.setup_return
    assert_nil func.return_val
    assert_instance_of LLVM::BasicBlock, func.return_block
    assert_equal LLVM::Script::Types::VOID, func.return_type
  end
  
  def test_method_missing
    func = make_function
    assert_raises(NoMethodError) do
      func.nonexistant_method
    end
    assert func.params
  end
  
  def test_respond_to
    func = make_function
    refute func.respond_to?(:nonexistant_method)
    assert func.respond_to?(:params)
  end
end 