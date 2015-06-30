# DeafShark
The DeafShark Programming Language implemented in Swift and LLVM

### How Do I Try It?
You can't do much yet...but if you really want to, [jump to the bottom](https://github.com/SlayterDev/DeafShark#try-it-out).

### Why?
Why not? Next question.

### Discussion
**Current Language Status:** Mostly Aimless

I've started writing this language because I've always enjoyed low level programming and making things to make other things.
There isn't exactly a problem this language is meant to solve. It's a programming language that can hopefully be used as a general
purpose programming language. I'm taking inspiration from the Swift syntax, though I want it to be different as well (hard as that
may be). I plan for this language to be suitable for things like systems programming to quick scripting. This is a learning
experience the whole way but let's hope something semi useful comes out of it.

**Implementation**

    [  Source File  ] -> [  Lexer  ] -> [  Parser  ] -> [  Compiler  ] -> [  Binary  ]

Code will be written in source files which is chopped into a large array of tokens by the lexer. The parser then analyzes the tokens
for syntax errors and creates an Abstract Syntax Tree. The compiler will then use this to translate the higher level code into 
LLVM IR "assembly" which will then be compiled into an executable binary.

**Sample Syntax**

    let x = 5 + 5
    var y as Int
    
    func add(x as Int, y as Int) -> Int {
      return x + y
    }

### Aknowledgments
Thank you to the [Nifty](https://github.com/mitchellallison/nifty) project by Mitchell Allison for giving me a jumpstart on
the lexer and parser for `DeafShark` since much of the syntax is similar to Swift.

### Try it out
* Make sure you have [LLVM](llvm.org) installed because you'll need it. I won't go into how to install this because it seems different for everyone, however building it from source seems like a good way to go.
* Next clone the repository and open up the Xcode project. 
* Create a file called `hello.ds` (or whatever you want so long as it ends with `.ds`). In that file put `print("Hello, World\n")`.
* You'll need to add the location of your source file as a commandline argument to the Scheme (upper left where it says `DeafShark`). 
* Optionally you can add the `-o` argument and another argument that is the location to store the output file (use the full path, otherwise it dumps the file with the debug executable).
* When you run the compiler, it will dump out the AST of the source as well as the LLVM IR code. This is mainly for debug purposes and will likely be removed in the future
* When the program finishes, you should have a file called `myFile.bc` or whatever you called it. This is LLVM bitcode which can then be run via `lli myFile.bc` in the Terminal

Congratulations! You just wrote and ran your first `DeafShark` program! Probably pretty underwhelming at this point in the development. In the future, the bitcode will be compiled into an executable that can be run directly without the need of `lli`. I also plan to have executable versions of the `DeafShark` compiler that can be run from the command line.
