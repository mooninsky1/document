@echo off

SET SourceFile=Server.rar
set "bd=%~dp0"
echo %bd%
cd ..

if exist  %SourceFile% (	
	cd %bd% 	
	WinRAR.exe x -icbk -y ../%SourceFile% ./ 
	echo "WinRAR ok"
) else (
	echo "../%SourceFile%" is not exist	
	pause 
	exit
)

cd %bd%
copy .\back\DBLoginServer.xml .\Server\
copy .\back\DBServer.xml .\Server\
copy .\back\DBZoneServer.xml .\Server\
copy .\back\DBPvpServer.xml .\Server\
copy .\back\DBPayServer.xml .\Server\
copy .\back\ZoneServerConfig.xml .\Server\Data
pause