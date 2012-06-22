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
  
  def test_collection
    obj = @space.library("testlib")
    assert_includes @space.collection, obj.name.to_sym
    assert_equal obj, @space.collection[obj.name.to_sym]
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
  
  def test_respond_to?
    obj = @space.library("testlib")
    refute @space.respond_to?(:nonexistant)
    assert @space.respond_to?(:testlib)
  end
end