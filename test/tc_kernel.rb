require 'script_test'
require 'llvm/script/kernel'

class TestKernel < MiniTest::Unit::TestCase  
  def check_factory(klass, methname)
    obj = send(methname, "test#{methname.to_s}")
    assert_instance_of klass, obj
    assert_equal obj, send(methname, "test#{methname.to_s}")
    assert_equal obj, send(methname)
  end
  
  def test_namespaces
    obj = LLVM::Script::Library.new("testlib")
    assert_includes namespaces, obj.name.to_sym
    assert_equal obj, namespaces[obj.name.to_sym]
  end
  
  def test_namespace
    check_factory(LLVM::Script::Namespace, :namespace)
  end
  
  def test_program
    check_factory(LLVM::Script::Program, :program)
  end
  
  def test_library
    check_factory(LLVM::Script::Library, :library)
  end
end