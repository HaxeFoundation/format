@echo off

:: BatchGotAdmin
:-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------


rm -rf release release.zip
mkdir release
set PATH=c:\progra~1\7-zip;%PATH%
haxe -xml haxedoc.xml --macro include('format',true,['format.tools.MemoryInput','format.tools.MemoryBytes','format.hxsl.Shader'])
cp -R format haxelib.json haxedoc.xml CHANGES.txt release
rm -rf release/*/.svn release/*/*/.svn
chmod -R 777 release
7z a -tzip release.zip release
rm -rf release
haxelib submit release.zip
pause