@echo off
rm -rf release release.zip
mkdir release
cp -R format haxelib.xml release
rm -rf release/.svn release/*/.svn
7z a -tzip release.zip release
rm -rf release
haxelib submit release.zip
pause