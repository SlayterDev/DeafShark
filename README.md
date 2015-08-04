# DeafShark
The DeafShark Programming Language implemented in Swift, Objective-C++, and LLVM

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
Checkout the Develop branch for the bleeding edge changes.

**Requirements**

Make sure you have [LLVM](llvm.org) installed because you'll need it. [Here is a quick guide](https://github.com/SlayterDev/DeafShark/wiki/Install-LLVM) for installing LLVM on OS X.

Also DeafShark uses swift 2. So you will need [Xcode 7](https://developer.apple.com/xcode/downloads/) (Beta 4 at the time of this writing).

**Build the Compiler**

* Clone the repository somewhere convenient. 
* Run the `OSXBuildScript.sh` script to build the compiler. It will dump the executable in a directory called `build` inside the current directory.
* Optionally move and/or rename the executable in the `build` directory wherever you like

**First Program**

* Create a file called `hello.ds` (or whatever you want so long as it ends with `.ds`). In that file put `println("Hello, World")`.
* Compile the program using `./DeafShark hello.ds`
* When the compiler finishes, you should have a binary file by the same name as your input file. 

-- If this didn't work, there is a chance your llvm executables are in a different place. Edit line 9 of the file `/usr/local/DeafShark/compileandlink.sh` to point to the location of `llc` on your machine. If this still doesn't work, then it is most likely because your using parts of the language that have not been developed yet.

Congratulations! You just wrote and ran your first `DeafShark` program! Probably pretty underwhelming at this point in the development. In the future, I plan to have executable versions of the `DeafShark` compiler that can be run from the command line.
