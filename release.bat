@echo off
rm -rf release release.zip
mkdir release
haxe -xml haxedoc.xml --macro include('format',true,['format.tools.MemoryInput','format.tools.MemoryBytes','format.hxsl.Shader'])
cp -R format haxelib.xml haxedoc.xml CHANGES.txt release
rm -rf release/*/.svn release/*/*/.svn
7z a -tzip release.zip release
rm -rf release
haxelib submit release.zip
pause