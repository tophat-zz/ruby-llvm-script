require 'script_test'

class TestProgram < MiniTest::Unit::TestCase
  
  def test_initialize
    prog = LLVM::Script::Program.new("testprog", :prefix => :all)
    assert_equal "testprog", prog.name
    assert_equal :none, prog.prefix
  end
  
  def test_main
    testcase = self
    prog = LLVM::Script::Program.new
    prog.private
    mfunc = prog.main do
      testcase.assert_instance_of LLVM::Script::Generator, self
      ret
    end
    assert_instance_of LLVM::Script::Function, mfunc
    assert_includes prog.functions, :main
  end
  
  def test_run
    prog = LLVM::Script::Program.new("testprog")
    assert_raises(RuntimeError) do
      prog.run
    end
    prog.main do
      sret 1
    end
    assert_equal 1, prog.run.to_i
  end
  
  def test_compile
    prog = LLVM::Script::Program.new("testprog")
    prog.main do
      sret 1
    end
    prog.compile("test_tmp")
    assert File.exists?("test_tmp")
    File.delete("test_tmp")
  end
  
  def test_verify
    prog = LLVM::Script::Program.new
    prog.main do
      sret 1
    end
    assert_empty capture_stderr { prog.verify }
  end
  
  def test_optimize
    prog = LLVM::Script::Program.new
    LLVM::PassManager.any_instance.expects(:gdce!)
    prog.optimize(:gdce)
  end
end