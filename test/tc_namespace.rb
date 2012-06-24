require 'script_test'

class TestNamespace < MiniTest::Unit::TestCase
  
  def setup
    @space = LLVM::Script::Namespace.new("TestSpace")
  end
  
  def check_factory(klass, methname)
    testcase = self
    obj = @space.__send__(methname, "testobj") do
      testcase.assert_instance_of klass, self
    end
    assert_instance_of klass, obj
    assert_equal obj, @space.__send__(methname, "testobj")
  end
  
  def check_collection(factory, methname)
    obj = @space.__send__(factory, "testobj")
    collection = @space.__send__(methname)
    assert_includes collection, obj.name.to_sym
    assert_equal obj, collection[obj.name.to_sym]
  end
  
  def test_build
    space = @space
    testcase = self
    space.build do
      testcase.assert_equal space, self
    end
  end
  
  def test_lookup
    obj = @space.library("testlib")
    assert_nil @space.lookup("nonexistant")
    assert_equal obj, @space.lookup("testlib")
    assert_equal obj, @space.testlib
    assert_equal obj, @space.lookup
    assert_equal obj, @space.last
  end
  
  def test_children
    obj = @space.library("testlib")
    assert_includes @space.children, obj.name.to_sym
    assert_equal obj, @space.children[obj.name.to_sym]
  end
  
  def test_namespace
    check_factory(LLVM::Script::Namespace, :namespace)
  end
  
  def test_library
    check_factory(LLVM::Script::Library, :library)
  end
  
  def test_program
    check_factory(LLVM::Script::Program, :program)
  end
  
  def test_namespaces
    check_collection(:namespace, :namespaces)
  end

  def test_libraries
    check_collection(:library, :libraries)
  end

  def test_programs
    check_collection(:program, :programs)
  end
  
  def test_respond_to?
    obj = @space.library("testlib")
    refute @space.respond_to?(:nonexistant)
    assert @space.respond_to?(:testlib)
  end
end