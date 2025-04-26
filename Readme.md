# Guten

Guten is a simple application designed for template expansion. It was initially
developed to support PDF production, though it doesn't directly handle PDFs.
The idea is to generate HTML, which can then be converted to a PDF using tools
like WeasyPrint.

To run the app, you only need to install lua on your machine. It doesn’t rely
on any external libraries.

The software is released under the MIT license by Mimmo Mane, 2025

Note: There is currently no test suite that’s fully functional or meaningful.

# Basic Usage

The basic usage is:

```
guten.lua infile.txt
```

This command will read infile.txt, expand the template inside it, and save the
result to infile.txt.out.

The template content is essentially lua code. We assume that you are already
familiar with the lua language. For more details, check the documentation on
the lua.org site.

The basic template syntax is `@{lua expression}`, which will be replaced by the
value of the lua expression. For example, if infile.txt contains:

```
1+1 = @{1+1}
```

Then, in infile.txt.out, you will get:

```
1+1 = 2
```

Additionally, lua statements (or partial statements) can be introduced with the
syntax `@{{lua statement}}`. These partial statements are merged into a single
lua script, and the text between them is treated as a function call to add that
text into the output. For example:

```
Hello @{{for k=1,3 do}}World @{{end}}!
```

This will produce:

```
Hello World World World !
```

Local and global variables, as well as functions, are supported:

```
@{{local count = 0; increase = function() count = count + 1 end}}
first value: @{count}
@{{count = count + 1}
second value: @{count}
@{{increase()}}
third value: @{count}]])
```

This will produce:

```

first value: 0
@{{count = count + 1}
second value: 0

third value: 1]] )
```

# Command line arguments

All command-line arguments starting with -- are stored in a table in the global
variable option, which can be used in the template. For example, if you run the
command:

```
guten.lua --foo=bar infile.txt
```

Then the template:

```
@{option.foo}
```

will be rendered as:

```
bar
```

The only argument that directly affects guten itself is --out, which sets the
output file path. --out is also available from the option variable as usual.
Additionally, the character % is replaced with the basename of the current
input file. Since guten can render multiple files at once, this is useful for
generating dynamic filenames. For example:

```
guten.lua --out=build/%.out infile-A.txt infile-B.txt
```

This will render infile-A.txt to build/infile-A.out, and infile-B.txt to
build/infile-B.out.

# Core functions

The standard Lua library functions are NOT available inside the template,
except for: `pairs`, `ipairs`.

Here’s a list of additional functions that are available:

`log` - Writes the arguments to the standard output. Useful for debugging.

`option` - Global table containing all the command-line arguments passed to `guten`

`readcommand` - Run the provided text though the system shell and returns its
standard output.

`date` - Returns a timestamp.

`include` - See the section on including other files.

`getmeta` - See the section on the initialization script.

`transform`, `mdtohtml`, `done` and `clear` - See the section on
transformations.

# Including other files

bla bla

TODO : explain !

# Initialization script

bla bla

TODO : explain !

# Transformation

bla bla

TODO : explain !

# Metadata

bla bla

TODO : explain !

