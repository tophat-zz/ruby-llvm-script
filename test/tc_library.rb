require 'script_test'

class TestLibrary < MiniTest::Unit::TestCase
  
  def test_dump
    lib = LLVM::Script::Library.new("testlib")
    refute_empty capture_stderr { lib.dump }
  end
  
  def test_build
    testcase = self
    lib = LLVM::Script::Library.new("testlib")
    lib.build do
      testcase.assert_equal lib, self
    end
  end
  
  def test_import
     LLVM::Script::Library.new("importee") do
      extern :printf, [LLVM::Script::Types::CHARPTR, LLVM::Script::Types::VARARGS], LLVM::Script::Types::INT
      global :ret_int, LLVM::Int.from_i(1)
      
      macro(:gret){ sret load(ret_int) }
      function :testing, [], LLVM::Script::Types::INT do
        self.printf "Testing"
        gret
      end
      
      private
      function :uncallable, [], LLVM::Script::Types::INT do
        self.printf "Uncallable"
        gret
      end
    end
    lib = LLVM::Script::Library.new("importer")
    lib.extern :printf, [LLVM::Script::Types::CHARPTR, LLVM::Script::Types::VARARGS], LLVM::Script::Types::INT
    lib.function :testing do
      self.printf "Testing"
      ret
    end
    refute_silent { lib.import 'importee' }
    assert_includes lib.functions,  :printf
    assert_includes lib.functions,  :testing
    assert_includes lib.functions,  :testing
    refute_includes lib.functions,  :uncallable
    assert_includes lib.globals,    :ret_int
    assert_includes lib.macros,     :gret
  end
  
  def test_import_global_conflict
    LLVM::Script::Library.new("importee") do
      global :testglobal, LLVM::Int.from_i(1)
    end
    lib = LLVM::Script::Library.new("importer")
    lib.global "rls.importee.testglobal", LLVM::Int
    refute_silent { lib.import 'importee' }
  end
  
  def test_import_errors
    lib = LLVM::Script::Library.new("testlib")
    assert_raises(ArgumentError) do
      lib.import("nonexistant")
    end
    assert_raises(ArgumentError) do
      lib.import(LLVM::Script::Program.new("non-importable"))
    end
  end
  
  def test_public
    lib = LLVM::Script::Library.new("testlib")
    lib.public
    assert_equal :public, lib.visibility
  end
  
  def test_private
    lib = LLVM::Script::Library.new("testlib")
    lib.private
    assert_equal :private, lib.visibility
  end
  
  def test_bad_visibility
    lib = LLVM::Script::Library.new("testlib")
    lib.visibility :bad
    assert_equal :public, lib.visibility
  end
  
  def test_visibility
    lib = LLVM::Script::Library.new("testlib")
    func = lib.function :testfunc
    refute_empty lib.functions
    lib.visibility :private, :testfunc
    assert_equal :private, func.linkage
    assert_empty lib.functions
    testcase = self
    lib.visibility :private do
      testcase.assert_equal :private, visibility
    end
    assert_raises(ArgumentError) do
      lib.visibility :private, :nonexistant
    end
    assert_equal :public, lib.visibility
    lib.visibility :private
    assert_equal :private, lib.visibility
  end
  
  def check_values(lib, collection, name)
    assert_includes lib.__send__(collection), name
    lib.private name
    refute_includes lib.__send__(collection), name
    assert_includes lib.__send__(collection, true), name
  end
  
  def test_functions
    lib = LLVM::Script::Library.new("testlib")
    func = lib.function :testfunc
    assert_equal func, lib.functions[:testfunc]
    check_values(lib, :functions, :testfunc)
  end
  
  def test_macros
    lib = LLVM::Script::Library.new("testlib")
    m = lib.macro(:testmacro){}
    assert_equal m, lib.macros[:testmacro]
    check_values(lib, :macros, :testmacro)
  end
  
  def test_globals
    lib = LLVM::Script::Library.new("testlib")
    glob = lib.global :testglobal, LLVM::Int
    assert_equal glob, lib.globals[:testglobal]
    check_values(lib, :globals, :testglobal)
  end
  
  def test_function
    testcase = self
    lib = LLVM::Script::Library.new("testlib")
    func = lib.function :testfunc do
      testcase.assert_instance_of LLVM::Script::Generator, self
      ret
    end
    refute_equal :testfunc, func.name.to_sym
    assert_instance_of LLVM::Script::Function, func
    assert_equal :external, func.linkage
  end
  
  def test_function_private
    lib = LLVM::Script::Library.new("testlib")
    lib.private
    pf = lib.function :privfunc
    assert_equal :private, pf.linkage 
  end
  
  def test_extern
    lib = LLVM::Script::Library.new("testlib")
    lib.private
    func = lib.extern :testfunc
    assert_includes lib.functions, :testfunc
    assert_instance_of LLVM::Script::Function, func
    assert_equal :external, func.linkage
  end
  
  def test_macro
    testcase = self
    lib = LLVM::Script::Library.new("testlib")
    m = lib.macro :testmacro do
      testcase.assert_instance_of LLVM::Script::Generator, self
    end
    assert_includes lib.macros, :testmacro
    assert_instance_of Proc, m
  end
  
  def test_global
    lib = LLVM::Script::Library.new("testlib")
    glob = lib.global :testglobal, 8
    refute_equal :testglobal, glob.name.to_sym
    assert_equal LLVM::Int.from_i(8), glob.initializer
    assert_instance_of LLVM::GlobalVariable, glob
    assert_equal :external, glob.linkage
  end
  
  def test_global_private
    lib = LLVM::Script::Library.new("testlib")
    lib.private
    pg = lib.global :privglobal, LLVM::Int.from_i(8)
    assert_equal :private, pg.linkage
  end
  
  def test_global_extern
    lib = LLVM::Script::Library.new("testlib")
    lib.private
    glob = lib.global :testglobal, LLVM::Int
    assert_includes lib.globals, :testglobal
    assert_equal :external, glob.linkage
  end
  
  def test_constant
    lib = LLVM::Script::Library.new("testlib")
    glob = lib.constant :testconstant, LLVM::Int.from_i(8)
    assert_instance_of LLVM::GlobalVariable, glob
    assert_equal 1, glob.global_constant?
  end
end