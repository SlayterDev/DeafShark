# DeafShark
The DeafShark Programming Language implemented in Swift and LLVM

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
