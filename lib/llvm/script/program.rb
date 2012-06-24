module LLVM
  module Script
    # An executable, compilable, optimizable library with a main function. It, however, is not a 
    # subclass of {LLVM::Script::Library} because it can not be imported.
    class Program < ScriptObject
      include Collection
      
      # Creates a new program.
      # @param [String] name The name of the program.
      # @param [LLVM::Script::Namespace] space The namespace in which this program resides.
      # @param [Proc] block A block with the insides of the program.
      # @return [LLVM::Script::Program] The new program.
      def initialize(name, space=DEFAULT_SPACE, &block)
        LLVM.init_x86
        @name = name.to_s
        @visibility = :public
        @module = LLVM::Module.new(name)
        @globals = {:public=>{}, :private=>{}}
        @functions = {:public=>{}, :private=>{}}
        @macros = {:public=>{}, :private=>{}}
        @namespace = space
        @namespace.add(self) if @namespace
        @address = namespace.nil? ? @name : "#{namespace.address}.#{@name.gsub(" ", "")}"
        build(&block) if ::Kernel.block_given?
      end
      
      # Creates the main function of the program. The main function takes the arguments `argc` 
      # and `argv` and returns a integer (usually 0 on success). If the function already exists,
      # it is just returned.
      # @example
      #   extern :printf, [CHARPTR, VAARGS], INT
      #   ...
      #   main do |argc, argv|
      #     printf("%d arguments were given to the main function.", argc)
      #     sret 0
      #   end
      # @param [Proc] block A block with the insides of the main function.
      def main(&block)
        unless @main
          @main = Function.new(self, @module, "main", [Types::INT, Types::VOIDPTRPTR], Types::INT)
          @functions[:public][:main] = @main
          @main.build(&block) if ::Kernel.block_given?
        end
        return @main
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
      
      # Verifys that the program is valid. Prints any problems to stdout.
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
        passes.each do |name|
          begin
            manager.__send__("#{name.to_s}!".to_sym) 
          rescue NoMethodError
            raise ArgumentError, "Unkown pass, #{name.to_s}, given to optimize."
          end
        end
        manager.run(@module)
      end
    end
  end
end