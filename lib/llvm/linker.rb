module LLVM
  module C
    extend FFI::Library
    path = File.join(File.dirname(__FILE__), '../', FFI.map_library_name('LLVMLinker-1.0.0'))
    linker_lib = File.expand_path(path)
    ffi_lib [linker_lib]
    
    # (Not documented)
    enum :linker_mode, [
      :linker_destroy_source, 0,
      :linker_perserve_source, 1
    ]
    
    # Links the source module into the destination module, taking ownership
    # of the source module away from the caller. Optionally returns a
    # human-readable description of any errors that occurred in linking.
    # OutMessage must be disposed with LLVMDisposeMessage. The return value
    # is true if an error occurred, false otherwise.
    # 
    # @method link_modules(dest, src, mode, out_message)
    # @param [FFI::Pointer(ModuleRef)] dest 
    # @param [FFI::Pointer(ModuleRef)] src 
    # @param [Symbol from _enum_linker_mode_] mode 
    # @param [FFI::Pointer(**CharS)] out_message 
    # @return [Integer] 
    # @scope class
    attach_function :link_modules, :LLVMLinkModules, [:pointer, :pointer, :linker_mode, :pointer], :int
  end

  class Module
    def link(other, mode)
      result = nil
      FFI::MemoryPointer.new(FFI.type_size(:pointer)) do |str|
        status = C.link_modules(self, other, mode, str)
        result = str.read_string if status == 1
        C.dispose_message str.read_pointer
      end
      result
    end
  end
end