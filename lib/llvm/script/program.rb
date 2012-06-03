module LLVM
  module Script
    # An executable, compilable, optimizable library with a main function.
    class Program < Library
      
      @@programs = {}       # @private
      @@last_program = nil  # @private
      
      # Retrieves an array of all programs that have been created.
      # @return [Array<LLVM::Script::Program>] An array of all programs.
      def self.programs
        return @@programs
      end
      
      # Retrieves the last created program.
      # @return [LLVM::Script::Program] The last created program.
      def self.last
        return @@last_program
      end
      
      # Creates a new program.
      # @param [String] name An optional name for the program. If you do not give one a unique id 
      #   will be generated using #make_uuid.
      # @param [Hash] opts Options for the new program, same as those for a library
      #   (except :prefix is ALWAYS :none).
      # @param [Proc] block A block with the insides of the program.
      # @return [LLVM::Script::Program] The new program.
      def initialize(name="", opts={}, &block)
        LLVM.init_x86
        opts[:prefix] = :none
        super(name, opts, &block)
        @@programs[name.to_s] = self
        @@last_program = self
      end
      
      # Creates the main function of the program. The main function takes the arguments `argc` 
      # and `argv` and returns a integer (usually 0 on success).
      # @example
      #   extern :printf, [CHARPTR, VAARGS], INT
      #   ...
      #   main do |argc, argv|
      #     printf("%d arguments were given to the main function.", argc)
      #     sret 0
      #   end
      # @param [Proc] block A block with the insides of the main function.
      def main(&block)
        @main ||= self.function(:main, [INT, VOIDPTRPTR], INT, &block)
        visibility(:public, @main.name)
      end
      
      # Runs the main function of the program.
      # @todo Figure out how to make a GenericValue from an array (in order to support args).
      # @return [LLVM::GenericValue] The result of the main function wrapped in a GenericValue.
      # @see http://jvoorhis.com/ruby-llvm/LLVM/GenericValue.html
      def run
        if @main.nil?
          raise RuntimeError, "Program, #{@name}, cannot be run without a main funcion."
        end
        @jit ||= LLVM::JITCompiler.new(@module)
        @jit.run_function(@main, GenericValue.from_i(0), GenericValue.from_i(0))
      end
      
      # Compiles the program into an executable binary.
      # @param [String] file The file to compile into.
      def compile(file)
        @module.write_bitcode("#{file}.bc")
        %x[/usr/local/bin/llc -disable-cfi #{file}.bc -o #{file}.s]
        %x[gcc #{file}.s -o #{file}]
        File.delete("#{file}.bc")
        File.delete("#{file}.s")
      end
      
      # Verifys that the program is valid. Prints any problems to $stdout.
      def verify
       @module.verify!
      end

      # Optimizes the program using the given passes.
      # @param [List<String, Symbol>] passes A list of optimization passes to run. Equivalent to the methods
      #   of LLVM::PassManager without the exclamation (!).
      # @see http://jvoorhis.com/ruby-llvm/LLVM/PassManager.html
      # @see http://llvm.org/docs/Passes.html 
      def optimize(*passes)
        @jit ||= LLVM::JITCompiler.new(@module)
        manager = LLVM::PassManager.new(@jit)
        passes.each{ |name| manager.__send__("#{name.to_s}!".to_sym) }
        manager.run(@module)
      end
    end
  end
end