@echo off
temploc2 tpl.mtt
nekoc index.neko
nekoc -d tpl.mtt.n -d index.n
neko test.n
pause
