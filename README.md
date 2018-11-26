[![TravisCI Build Status](https://travis-ci.org/HaxeFoundation/format.svg?branch=master)](https://travis-ci.org/HaxeFoundation/format)

The `format` library contains support for different file-formats for the Haxe programming language.

Formats
=======

Currently supported formats are :


| Format | Description | Reader | Writer |
|---|---|---|---|
| ABC | Flash AS3 bytecode format | ☑ | ☑ |
| AGAL | Adobe Shader Assembler for Stage3D | ❌ | ☑ |
| AMF | Flash serialized object | ☑ | ☑ |
| AS1 | Adobe ActionScript1-2 bytecode in SWF | ☑ | ❌ |
| BMP | Bitmap Image format | ☑ | ☑ |
| ELF | Executable and Linkable Format | ☑ | ❌ |
| FLV | Flash Video | ☑ | ☑ |
| GIF | Image file format | ☑ | ☑ |
| GZ | Compressed file | ☑ | ❌ |
| HL | HashLink | ☑ | ❌ |
| JPG | Image file format | ❌ | ☑ |
| LZ4 | Compressed file | ☑ | ❌ |
| MP3 | Compressed audio | ☑ | ☑ |
| NEKO | NekoVM bytecode | ☑ | ❌ |
| PBJ | PixelBender Binary file | ☑ | ☑ |
| PDF | Only generic file structure and partial decryption | ☑ | ❌ |
| PEX | Particle effect format | ☑ | ❌ |
| PNG | Image file format | ☑ | ☑ |
| SWF | Flash file format | ☑ | ☑ |
| TAR | Compressed Archive | ☑ | ☑ |
| TGA | TARGA Image file format; Reader/Writer does not support developer data chunk; Writer does not support RLE encoding | ☑ | ☑ |
| TGZ | TAR+GZ Archive | ☑ | ❌ |
| WAV | Raw sound | ☑ | ☑ |
| ZIP | Compressed Archive | ☑ | ☑ |

Documentation
=============

Automatically generated API documentation is here: https://haxefoundation.github.io/format/format/

Installation
============

Available on haxelib, simply run the following command : `haxelib install format`. To use the library, simply add `-lib format` to your commandline parameters.

Package Structure
=================

Each format lies in its own package, for example `format.pdf` contains classes for PDF.

The `format.tools` package contain some tools that might be shared by several formats but don't belong to a specific one.

Each format must provide the following files :
  * one `Data.hx` file that contain only data structures / enums used by the format. If there is really a lot, they can be separated into several files, but it's often my easy for the end user to only have to do one single `import format.xxx.Data` to access to all the defined types.
  * one `Reader.hx` class which enable to read the file format from an `haxe.io.Input`
  * one `Writer.hx` class which enable to write the file format to an `haxe.io.Output`
  * some other classes that might be necessary for manipulating the data structures

It's important in particular that the data structures storing the decoded information are separated from the actual classes manipulating it. This enable full access to all the file format infos and the ability to easily write libraries that manipulate the format, even if later the Reader implementation is changed for example.

Contributing
============

We're accepting contributions if they are following the package structure rules (see above), please send them as Pull Requests.
