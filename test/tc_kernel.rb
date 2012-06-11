require 'script_test'
require 'llvm/script/kernel'

class TestKernel < MiniTest::Unit::TestCase  
  def check_factory(klass, methname)
    obj = send(methname, "testobj"){}
    assert_instance_of klass, obj
    assert_equal obj, send(methname, "testobj")
    assert_equal obj, send(methname)
    assert_raises(ArgumentError) do
      program("nonexistant")
    end
  end
  
  def check_collection(klass, methname)
    obj = klass.new("testobj")
    collection = send(methname)
    assert_includes collection, obj.name.to_sym
    assert_equal obj, collection[obj.name.to_sym]
  end
  
  def test_program
    check_factory(LLVM::Script::Program, :program)
  end
  
  def test_programs
    check_collection(LLVM::Script::Program, :programs)
  end
  
  def test_library
    check_factory(LLVM::Script::Library, :library)
  end
  
  def test_libraries
    check_collection(LLVM::Script::Library, :libraries)
  end
end