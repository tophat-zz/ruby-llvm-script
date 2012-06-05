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

## Getting Started

<table>
  <tr>
    <th>Notice</th><td>ruby-llvm-script is currently not released as a gem (will be soon). You will, for now, have to rake it from the source if you wish to use it.</td>
  </tr>
</table>

If you would like to see what ruby-llvm-script feels like before getting started, take a look at the [Hello World program](https://github.com/tophat/ruby-llvm-script/wiki/Hello-World). Otherwise, you will need to [install LLVM and ruby-llvm-script](https://github.com/tophat/ruby-llvm-script/wiki/Installation) first. After you are done with that, you might wish to take a look at the breakdowns of the example programs in the samples directory: 

1. Hello World: [hello.rb](https://github.com/tophat/ruby-llvm-script/wiki/Hello-World)
2. Factorial: [factorial.rb](https://github.com/tophat/ruby-llvm-script/wiki/Factorial)
3. I/O: [io.rb](https://github.com/tophat/ruby-llvm-script/wiki/IO)
4. Conditionals: [cond.rb](https://github.com/tophat/ruby-llvm-script/wiki/Conditionals)
5. Function Pointers: [fp.rb](https://github.com/tophat/ruby-llvm-script/wiki/Function-Pointers)

It is advised to look at them in the above order because as each builds upon the last.

## Moving On

You might want to look at the ruby-llvm documentation at <http://jvoorhis.com/ruby-llvm> and the LLVM assembly language reference at <http://llvm.org/docs/LangRef.html> if you want to get in real deep.
