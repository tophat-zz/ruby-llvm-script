require 'script_test'

class TestGenerator < MiniTest::Unit::TestCase
  
  def setup
    @lib = LLVM::Script::Library.new("testlib")
    @fun = @lib.function :genfunc
    @mod = @fun.instance_eval{ @module }
    @gen = LLVM::Script::Generator.new(@lib, @mod, @fun)
  end
  
  def exec(type=LLVM::Int, &block)
    prog = LLVM::Script::Program.new("testprog")
    func = prog.function :testfunc, [], type do
      val = instance_eval(&block)
      sret(val) unless finished?
    end
    jit ||= LLVM::JITCompiler.new(prog.to_ptr)
    result = jit.run_function(func)
    type = LLVM::Type(type)
    return type.kind_of?(LLVM::IntType) ? (type.width == 1 ? result.to_b : result.to_i) : result.to_f(type)
  end
  def bexec(&block) exec(LLVM::Int1, &block) end
  def fexec(&block) exec(LLVM::Float, &block) end
  def conv(func, val, type, *args) exec(type){ __send__(func, val, type, *args) } end
  def comp(op, lhs, rhs) exec(LLVM::Int1){ opr(op, lhs, rhs) } end
  
  def test_args
    assert_equal @fun.args, @gen.args
  end
  
  def test_call
    @lib.macro(:mret) { |x| sret x }
    tf = @lib.function(:callee, [], LLVM::Int) { mret 8 }
    dc = @lib.function(:do_call, [tf.pointer], LLVM::Int) { |fp| sret call(fp) }
    main = @lib.function(:testfunc, [], LLVM::Int) do
      sret do_call(tf)
    end
    assert_equal 8, exec { call(tf) }
    jit ||= LLVM::JITCompiler.new(@lib.to_ptr)
    assert_equal 8, jit.run_function(main).to_i
    assert_raises(ArgumentError) { @gen.call(:mret, 8, 2) }
    assert_raises(ArgumentError) { @gen.call(8) }
    assert_raises(NoMethodError) { @gen.call(:nonexistant) }
  end
  
  def test_global
    @lib.global :testglobal, LLVM::Int(1)
    @lib.global :privglobal, LLVM::Int(1)  
    assert_equal @lib.globals[:testglobal], @gen.global(:testglobal)
    assert_equal @lib.globals(true)[:privglobal], @gen.global(:privglobal)
  end
  
  def test_neg
    assert_equal 0,     exec  { neg(0) }
    assert_equal 1,     exec  { neg(-1) }
    assert_equal -1.5,  fexec { neg(1.5) }
    assert_equal 0, exec { neg("This should be forced into a number") }
  end
  
  def test_inc
    assert_equal 31, exec {
      ptr = alloca(LLVM::Int)
      store(5, ptr)
      inc(ptr, 25)
      load(inc(ptr))
    }
    assert_in_delta 11.1, fexec {
      ptr = alloca(LLVM::Float)
      store(7.8, ptr)
      inc(ptr, 2.3)
      load(inc(ptr))
    }
    assert_raises(ArgumentError) { @gen.inc(1) }
  end
  
  def test_dec
    assert_equal 8, exec {
      ptr = alloca(LLVM::Int)
      store(11, ptr)
      dec(ptr, 2)
      load(dec(ptr))
    }
    assert_in_delta 5.4, fexec {
      ptr = alloca(LLVM::Float)
      store(7.8, ptr)
      dec(ptr, 1.4)
      load(dec(ptr))
    }
    assert_raises(ArgumentError) { @gen.dec(1.5) }
  end
  
  def test_add
    assert_equal 18, exec { add(8, 10)  }
    assert_equal -9, exec { add(-15, 6) }
    assert_in_delta 12.5, fexec { add(7.5, 5)     }
    assert_in_delta -7.1, fexec { add(-2.8, -4.3) }
    assert_in_delta 21.2, fexec { add(2.1, 19.1)  }
    assert_equal 0, exec { add("non", "numbers") }
  end
  
  def test_sub
    assert_equal 12, exec { sub(18, 6)  }
    assert_equal -7, exec { sub(-5, 2)  }
    assert_in_delta 14.5, fexec { sub(18.5, 4)    }
    assert_in_delta  2.5, fexec { sub(-2.3, -4.8) }
    assert_in_delta 11.1, fexec { sub(16.2, 5.1)  }
    assert_equal 0, exec { sub("non", "numbers") }
  end
  
  def test_mul
    assert_equal 30, exec { mul(15, 2)  }
    assert_equal -8, exec { mul(-2, 4)  }
    assert_in_delta 14.4, fexec { mul(3.6, 4)     }
    assert_in_delta 4.41, fexec { mul(-2.1, -2.1) }
    assert_in_delta 4.48, fexec { mul(3.2, 1.4)   }
    assert_equal 0, exec { mul("non", "numbers") }
  end
  
  def test_div
    assert_equal 11, exec { div(22, 2, false)  }
    assert_equal -2, exec { div(-5, 2)  }
    assert_in_delta  3.2, fexec { div(12.8, 4)    }
    assert_in_delta 16.4, fexec { div(-8.2, -0.5) }
    assert_in_delta  4.0, fexec { div(16.4, 4.1)  }
    assert_raises(ZeroDivisionError) do  
      exec { div("0/0 is undefined", "this would be forced into zero") }
    end
    assert_raises(ZeroDivisionError) {  @gen.div(5, 0) }
  end
  
  def test_rem
    assert_equal  1, exec { rem(15, 2, false)  }
    assert_equal -1, exec { rem(-9, 2)  }
    assert_in_delta 0.2,  fexec { rem(16.2, 4)    }
    assert_in_delta -0.2, fexec { rem(-8.2, -0.5) }
    assert_in_delta 1.8,  fexec { rem(4.1, 2.3)   }
    assert_in_delta 0.6,  fexec { rem(6.2, -1.4)  }
    assert_raises(ZeroDivisionError) do  
      exec { rem("0/0 is undefined", "this would be forced into zero") }
    end
    assert_raises(ZeroDivisionError) {  @gen.rem(8, 0) }
  end
  
  def test_shl
    assert_equal 60,          exec { shl(15, 2)             }
    assert_equal 65536,       exec { shl(1, 16)             }
    assert_equal -8126464,    exec { shl(-31, 18)           }
    assert_equal -2147483648, exec { shl(1, 31)             }
    assert_equal 0,           exec { shl(65536, 31)         }
    assert_equal 0,           exec { shl("non", "numbers")  }
  end
  
  def test_ashr
    assert_equal 30,          exec { ashr(60, 1)            }
    assert_equal 1,           exec { ashr(65536, 16)        }
    assert_equal -1,          exec { ashr(-1, 1)            }
    assert_equal -8,          exec { ashr(-16, 1)           }
    assert_equal -16,         exec { ashr(-64, 2)           }
    assert_equal 0,           exec { ashr(0, 1)             }
    assert_equal 0,           exec { ashr("non", "numbers") }
  end
  
  def test_lshr
    assert_equal 30,          exec { lshr(60, 1)            }
    assert_equal 1,           exec { lshr(65536, 16)        }
    assert_equal 2147483647,  exec { lshr(-1, 1)            }
    assert_equal 2147483640,  exec { lshr(-16, 1)           }
    assert_equal 1073741808,  exec { lshr(-64, 2)           }
    assert_equal 0,           exec { lshr(0, 1)             }
    assert_equal 0,           exec { lshr("non", "numbers") }
  end
  
  def test_bitcast
    str = LLVM::Script::Convert("Testing")
    sptr = @gen.bitcast(str, LLVM::Script::Types::CHARPTR)
    assert_equal :pointer, sptr.type.kind
    assert_equal 8, sptr.type.element_type.width
    assert_raises(ArgumentError) { @gen.bitcast(str, "Not a type") }
  end
  
  def test_trunc
    assert_equal 345,   conv(:trunc, 345,         LLVM::Int16)
    assert_equal -565,  conv(:trunc, -565,        LLVM::Int16)
    assert_equal 1,     conv(:trunc, -2147483647, LLVM::Int16)
    assert_equal 0,     conv(:trunc, 65536,       LLVM::Int16)
    assert_equal -5536, conv(:trunc, 125536,      LLVM::Int16)
    assert_in_delta 3.125, conv(:trunc, LLVM::Double(3.125), LLVM::Float)
    assert_in_delta -14.7, conv(:trunc, LLVM::Double(-14.7), LLVM::Float)
    assert_equal 0, conv(:trunc, "Not a number", LLVM::Int8)
    assert_raises(ArgumentError) { @gen.trunc(50, "Not a type") }
  end
  
  def test_sext
    assert_equal 345, conv(:sext, 345,  LLVM::Int64)
    assert_equal -1,  conv(:sext, true, LLVM::Int32)
    assert_equal -1,  conv(:sext, LLVM::Int8.from_i(-1), LLVM::Int16)
    assert_in_delta 3.125, conv(:sext, 3.125, LLVM::Double)
    assert_in_delta -14.7, conv(:sext, -14.7, LLVM::Double)
    assert_equal 0, conv(:sext, "Not a number", LLVM::Int64)
    assert_raises(ArgumentError) { @gen.sext(50, "Not a type") }
  end
  
  def test_zext
    assert_equal 345, conv(:zext, 345,  LLVM::Int64)
    assert_equal 1,   conv(:zext, true, LLVM::Int32)
    assert_equal 255, conv(:zext, LLVM::Int8.from_i(-1), LLVM::Int16)
    assert_in_delta 3.125, conv(:zext, 3.125, LLVM::Double)
    assert_in_delta -14.7, conv(:zext, -14.7, LLVM::Double)
    assert_equal 0, conv(:zext, "Not a number", LLVM::Int64)
    assert_raises(ArgumentError) { @gen.zext(50, "Not a type") }
  end
  
  def test_ftoi
    assert_equal 12, conv(:ftoi, 12.8,                LLVM::Int32, false)
    assert_equal -5, conv(:ftoi, -5.2,                LLVM::Int32)
    assert_equal 18, conv(:ftoi, LLVM::Double(18.2),  LLVM::Int32)
    assert_equal  0, conv(:ftoi, "Not a number",      LLVM::Int32)
    assert_raises(ArgumentError) { @gen.ftoi(21.2, "Not a type") }
  end
  
  def test_itof
    assert_equal 12.0, conv(:itof, 12, LLVM::Float, false)
    assert_equal -5.0, conv(:itof, -5, LLVM::Float)
    assert_equal 18.0, conv(:itof, 18, LLVM::Double)
    assert_equal  0.0, conv(:itof, "Not a number", LLVM::Float)
    assert_raises(ArgumentError) { @gen.itof(50, "Not a type") }
  end
  
  def test_ptrtoint_and_inttoptr
    testcase = self
    assert bexec {
      ptr = alloca(LLVM::Int)
      store(800, ptr)
      int = ptrtoint(ptr, LLVM::Int64)
      testcase.assert_equal LLVM::Int64.type, int.type
      nptr = inttoptr(int, ptr.type)
      testcase.assert_equal :pointer, nptr.type.kind
      opr(:eq, load(ptr), load(nptr))
    }
    ptr = @gen.alloca(LLVM::Int)
    assert_raises(ArgumentError) { @gen.ptrtoint(ptr, "Not a type") }
    assert_raises(ArgumentError) { @gen.ptrtoint(8, LLVM::Int) }
    assert_raises(ArgumentError) { @gen.inttoptr(ptr, "Not a type") }
  end
  
  def test_diff
    assert_equal 1, exec(LLVM::Int64) {
      ptr = alloca(LLVM::Int)
      ptr2 = alloca(LLVM::Int)
      diff(ptr, ptr2)
    }
  end
  
  def test_cast
    assert_equal 12, conv(:cast, 12,   LLVM::Int64)
    assert_equal -8, conv(:cast, -8,   LLVM::Int64)
    assert_in_delta -5.8, conv(:cast, -5.8, LLVM::Double)
    assert_in_delta 1.82, conv(:cast, 1.82, LLVM::Double)
    voidptr = @gen.alloca(LLVM::Script::Types::VOIDPTR)
    voidpp = @gen.cast(voidptr, LLVM::Script::Types::VOIDPTRPTR)
    assert_equal :pointer, voidpp.type.element_type.kind
    assert_raises(ArgumentError) { @gen.cast("Unacceptable", LLVM::Int64)}
    assert_raises(ArgumentError) { @gen.cast(50, "Not a type") }
  end
  
  def test_alloca
    ptr = @gen.alloca(LLVM::Float)
    ary = @gen.alloca(LLVM::Int8, 20)
    assert_equal :pointer,  ptr.type.kind
    assert_equal :pointer,  ary.type.kind
    assert_equal :float,    ptr.type.element_type.kind
    assert_equal :integer,  ary.type.element_type.kind
    assert_raises(ArgumentError) { @gen.alloca("Not a type") }
  end
  
  def test_malloc
    ptr = @gen.malloc(LLVM::Double)
    ary = @gen.malloc(LLVM::Int8, 50)
    assert_equal :pointer,  ptr.type.kind
    assert_equal :pointer,  ary.type.kind
    assert_equal :double,   ptr.type.element_type.kind
    assert_equal :integer,  ary.type.element_type.kind
    assert_raises(ArgumentError) { @gen.malloc("Not a type") }
  end
  
  def test_free
    assert @gen.free(@gen.malloc(LLVM::Int))
    assert_raises(ArgumentError) { @gen.free(45) }
  end
  
  def test_load_and_store
    assert_equal 8, exec {
      ptr = alloca(LLVM::Int)
      store(8.2, ptr)
      load(ptr)
    }
    assert_raises(ArgumentError) { @gen.load(82) }
    assert_raises(ArgumentError) { @gen.store(15) }
  end
  
  def test_gep
    assert_equal 32, exec {
      struct = alloca(LLVM::Script::Struct.new(:int => LLVM::Int))
      intptr = gep(struct, 0, 0)
      store(32, intptr)
      load(intptr)
    }
    assert_raises(ArgumentError) { @gen.gep(31) }
  end
  
  def test_gev
    assert_equal 58, exec {
      struct = alloca(LLVM::Script::Struct.new(:int => LLVM::Int))
      sep(struct, 0, :int, 58.5)
      gev(struct, :int)
    }
    assert_raises(ArgumentError) { @gen.gev(63) }
  end
  
  def test_sep
    assert_equal 21, exec {
      struct = alloca(LLVM::Script::Struct.new(:int => LLVM::Int))
      ptr = sep(struct, :int, 21.8)
      load(ptr)
    }
    assert_raises(ArgumentError) { @gen.sep(17) }
  end
  
  def test_insert
    assert_equal 27, exec {
      ary = insert([5, 10, 8], 27, 2)
      extract(ary, 2)
    }
    assert_equal 6, exec {
      const = LLVM::ConstantVector.const([LLVM::Int(21), LLVM::Int(53)])
      vec = insert(const, 6, 1)
      extract(vec, 1)
    }
  end
  
  def test_extract
    assert_equal 7,  exec { extract([4, 7, 2], 1) }
    assert_equal 18, exec { extract(LLVM::ConstantVector.const([LLVM::Int(18), LLVM::Int(42)]), 0) }
  end
  
  def test_shuffle
    assert_equal 8, exec { 
      nvec = shuffle([1, 2, 3], [4, 5, 6], [5, 2, 3, 1, 4, 0])
      add extract(nvec, 1), extract(nvec, 4)
    }
  end
  
  def test_invert
    assert bexec { invert(false) }
    assert_equal -2147483648, exec { invert(2147483647) }
  end
  
  def test_is_null
    refute bexec { is_null(LLVM::Int(8)) }
    assert bexec { is_null(LLVM::Int.type.null) }
    assert_raises(ArgumentError) { @gen.is_null("Not a LLVM::Value") }
  end
  
  def test_is_not_null
    assert bexec { is_not_null(LLVM::Int(8)) }
    refute bexec { is_not_null(LLVM::Int.type.null) }
    assert_raises(ArgumentError) { @gen.is_not_null("Not a LLVM::Value") }
  end
  
  def test_opr
    assert comp(:eq, 1, 1)
    refute comp(:ne, 1, 1)
    refute comp(:ugt, 2, 2)
    assert comp(:uge, 2, 1)
    refute comp(:ult, 1, 1)
    assert comp(:ule, 1, 2)
    refute comp(:sgt, -2, 2)
    refute comp(:sge, -2, 1)
    assert comp(:slt, -1, 2)
    assert comp(:sle, -1, 2)
    assert comp(:oeq, 1.0, 1.0)
    refute comp(:one, 1.0, 1.0)
    refute comp(:ogt, 2.0, 2.0)
    assert comp(:oge, 2.0, 1.0)
    refute comp(:olt, 1.0, 1.0)
    assert comp(:ole, 1.0, 2.0)
    assert comp(:ord, 1.0, 2.0)
    assert comp(:ueq, 1.0, 1.0)
    refute comp(:une, 1.0, 1.0)
    refute comp(:ugt, 2.0, 2.0)
    assert comp(:uge, 2.0, 1.0)
    refute comp(:ult, 1.0, 1.0)
    assert comp(:ule, 1.0, 2.0)
    refute comp(:uno, 1.0, 2.0)
    assert comp(:or, true, false)
    refute comp(:and, true, false)
    refute comp(:xor, true, true)
    assert_raises(ArgumentError) { comp(:unkown, 1, 2) }
  end
  
  def test_block
    testcase = self
    klass = @gen.class
    block = @gen.block do
      testcase.assert_instance_of klass, self
    end
    assert_instance_of klass, block
  end
  
  def test_select
    assert_equal 8,  exec { select true,  8, 10 }
    assert_equal 10, exec { select false, 8, 10 }
    assert_equal 7,  exec { select "str", 4, 7  }
  end
  
  def test_cond
    refute bexec {
      cond false do
        sret true
      end
      sret false
    }
    assert bexec {
      pret false
      cond true, proc {
        pret true
      }, nil, return_block
    }
    refute bexec {
      cond false, proc {
        sret true
      }, proc {
        sret false
      }
      sret true
    }
    assert bexec {
      cond true, block {
        sret true
      }, block {
        sret false
      }
      sret false
    }
    assert_raises(ArgumentError) { @gen.cond(true) }
  end
  
  def test_lp
    assert_equal 10, exec { 
      load(lp(0, proc{|i| opr(:ult, i, 10)}, proc{|i_ptr| inc(i_ptr)}))
    }
    assert_equal 15, exec { 
      pret -1
      ptr = alloca(LLVM::Int)
      store(0, ptr)
      lp(nil, proc{opr(:ult, load(ptr), 15)}, nil, return_block) do
        pret load(inc(ptr))
      end
    }
    assert_equal 7, exec { 
      lp do 
        sret 7
      end
      sret -1
    }
    assert_raises(ArgumentError) { @gen.lp(nil) }
  end
  
  def test_br
    @gen.br(@gen.block{ sret })
    assert @gen.finished?
  end
  
  def test_ret
    testcase = self
    exec(LLVM::Type.void) {
      testcase.assert_nil return_block
      ret
      testcase.assert finished?
      testcase.assert_nil return_block
    }
    assert_equal 9, exec {
      testcase.assert_nil return_block
      ret 9
      testcase.assert_instance_of LLVM::BasicBlock, return_block
    }
  end
  
  def test_cret
    testcase = self
    exec(LLVM::Type.void) {
      testcase.assert_nil return_block
      cret true
      testcase.refute finished?
      testcase.assert_instance_of LLVM::BasicBlock, return_block
    }
    assert_equal 12, exec {
      testcase.assert_nil return_block
      cret false, 4, block { ret 12 }
      testcase.assert finished?
      testcase.assert_instance_of LLVM::BasicBlock, return_block
    }
  end
  
  def test_sret
    testcase = self
    exec(LLVM::Type.void) {
      testcase.assert_nil return_block
      sret
      testcase.assert finished?
      testcase.assert_nil return_block
    }
    assert_equal 7, exec {
      testcase.assert_nil return_block
      testcase.assert_raises(ArgumentError) { sret }
      sret 7
      testcase.assert finished?
      testcase.assert_nil return_block
    }
  end
  
  def test_pret
    testcase = self
    exec(LLVM::Type.void) {
      testcase.assert_nil return_block
      pret
      testcase.refute finished?
      testcase.assert_instance_of LLVM::BasicBlock, return_block
    }
    assert_equal 21, exec {
      testcase.assert_nil return_block
      pret 21
      testcase.refute finished?
      testcase.assert_instance_of LLVM::BasicBlock, return_block
      br return_block
    }
  end
  
  def test_return_block
    assert_equal @fun.return_block, @gen.return_block
  end
  
  def test_unreachable
    refute @gen.finished?
    @gen.unreachable
    assert @gen.finished?
  end
  
  def test_finish
    refute @gen.finished?
    @gen.finish
    assert @gen.finished?
  end
  
  def test_method_missing
    @lib.function(:testfunc)
    @lib.macro(:testmacro){ true }
    @lib.global(:testglobal, LLVM::Int(1))
    assert @gen.testfunc
    assert @gen.testmacro
    assert @gen.testglobal
    assert_raises(NoMethodError) { @gen.nonexistant }
  end
  
  def test_respond_to
    @lib.function(:testfunc)
    @lib.macro(:testmacro){}
    @lib.global(:testglobal, LLVM::Int(1))
    assert @gen.respond_to?(:testfunc)
    assert @gen.respond_to?(:testmacro)
    assert @gen.respond_to?(:testglobal)
    refute @gen.respond_to?(:nonexistant)
  end
end