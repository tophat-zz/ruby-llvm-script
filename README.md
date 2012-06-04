# LLVM Script

<table>
  <tr>
    <th>Author</th><td>Mac Malone</td>
  </tr>
  <tr>
    <th>Copyright</th><td>Copyright (c) 2012 Mac Malone</td>
  </tr>
  <tr>
    <th>License</th><td>BSD 3-clause (see {file:LICENSE})</td>
  </tr>
</table>

## Introduction

This project aims to make a simple clean interface on top of ruby-llvm to make it 
easier for one to write ruby-llvm programs and libraries. It is also very well documented,
if I do say so myself.

ruby-llvm-script has been tested on OS X 10.7 using the following Ruby interpreters:

* MRI 1.8.7-p357
* MRI 1.9.3-p194

## Roadmap
* Make sure everything works.
* *Requests appreciated.*

## Installing

In order to install ruby-llvm-script you will ned to install ruby-llvm (http://github.com/jvoorhis/ruby-llvm).

<table>
  <tr>
    <th>Notice</th><td>ruby-llvm-script is currently not released as a gem (will be soon). You will, for now, have to rake it from the source if you wish to use it.</td>
  </tr>
</table>

Then you can install ruby-llvm-script with:

	sudo gem install ruby-llvm-script

## Getting Started

Lets take a look a basic hello world program in ruby-llvm-script (derived from `hello.rb` in the samples directory):

```ruby
require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'
	
program "Hello World" do
	extern :printf, [CHARPTR, VARARGS], INT
		
	main do
		printf("Hello World")
		sret 0
	end
end
	
program.run	# => Hello World
```
	
### Breakdown

Now let's break the example down.

```ruby
require 'rubygems'
require 'llvm/script'
require 'llvm/script/kernel'
```
	
These lines require ruby-llvm-script. The `require llvm/script/kernel` line enables us to 
use the global function `program`.

```ruby
program "Hello World" do ... end
```
	
This defines a new LLVM::Script::Program with the name Hello World and instance evaluates 
the code between `do` and `end`.

```ruby
extern :printf, [CHARPTR, VARARGS], INT
```
	
This makes the C function `printf` available to the program. `printf` takes a single `char*` for its
format string and then a variable number of arguments to be substituted into the string (like the ruby printf).
For more information on printf see: http://www.cplusplus.com/reference/clibrary/cstdio/printf/.

```ruby
main do ... end
```
	
This defines the `main` function of the program. This is equivalent to the C main function and is
run when the either the compiled version of the program is run or LLVM::Script::Program#run is called.

```ruby
printf("Hello World")
```
	
This just calls `printf` with the string "Hello World". Nothing too fancy, ruby-llvm-script is
able to convert Ruby strings (and other ruby types) into their LLVM equivalents. However, if
you are running Ruby 1.8.x you will have to call `self.printf`, because the new `printf` function
might conflict with the existing printf function (this is solved via the use of BasicObject 
in 1.9.x).

```ruby
sret 0
```
	
This returns 0. All LLVM functions must have a return statement even if they return void.
The 's' in `sret` tells ruby-llvm-script that you don't want it to add a return block, like
it (and gcc and clang) would. This is solely for optimization purposes, it will still work
the same if you just used `ret`.

```ruby
program.run
```
	
Since `program` is called without arguments, it returns the last created program. It then calls
LLVM::Script::Program#run which runs the `main` function.

## Moving On

For more ruby-llvm-script examples, look in the sample directory. Also, you will probably need to
look at the ruby-llvm documentation at http://jvoorhis.com/ruby-llvm and the LLVM assembly language reference at
http://llvm.org/docs/LangRef.html if you want to get in real deep.
