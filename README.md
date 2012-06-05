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

This project aims to make a simple, clean interface on top of ruby-llvm to make it 
easier for one to write ruby-llvm programs and libraries. It is also very well documented,
if I do say so myself.

ruby-llvm-script has been tested on OS X 10.7 using the following Ruby interpreters:

* MRI 1.8.7-p357
* MRI 1.9.3-p194

## Roadmap
* Make sure everything works.
* *Requests appreciated.*

## Installing

If you want to install ruby-llvm-script, you will need to install LLVM. You can learn how to do both 
on the [Installation](https://github.com/tophat/ruby-llvm-script/wiki/Installation) wiki page.

<table>
  <tr>
    <th>Notice</th><td>ruby-llvm-script is currently not released as a gem (will be soon). You will, for now, have to rake it from the source if you wish to use it.</td>
  </tr>
</table>

## Getting Started

Here is a hello world program in ruby-llvm-script:

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
  
program.run # => Hello World
```
  
If wish to fully understand what the above is doing, look [here](https://github.com/tophat/ruby-llvm-script/wiki/Hello-World).
There are also examples for a [Factorial](https://github.com/tophat/ruby-llvm-script/wiki/Factorial), [I/O](https://github.com/tophat/ruby-llvm-script/wiki/IO), [Conditionals](https://github.com/tophat/ruby-llvm-script/wiki/Conditionals), and [Function Pointers](https://github.com/tophat/ruby-llvm-script/wiki/Function-Pointers) on the wiki.

## Moving On

You might want to look at the ruby-llvm documentation at <http://jvoorhis.com/ruby-llvm> and the LLVM assembly language reference at <http://llvm.org/docs/LangRef.html> if you want to get in real deep.
