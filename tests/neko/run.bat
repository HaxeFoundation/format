@echo off
temploc2 tpl.mtt
nekoc -d tpl.mtt.n
neko test.n
pause
