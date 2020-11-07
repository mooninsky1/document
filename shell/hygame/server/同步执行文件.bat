echo off

copy/y C:\code\Server\Resource\Server\*.dll C:\Bin
copy/y C:\code\Server\Resource\Server\*.exe C:\Bin
copy/y C:\code\Server\Resource\Server\*.dll  .\Server
copy/y C:\code\Server\Resource\Server\*.exe .\Server
copy/y C:\code\Server\Resource\Server\DBServerProcedure.xml .\Server
copy/y C:\code\Server\Resource\Server\DBLogServerProcedure.xml .\Server
copy/y C:\code\Server\Resource\Server\DBPvpServerProcedure.xml .\Server

del/q C:\Bin\LoginServer_rd.exe
del/q C:\Bin\PayServer_rd.exe
del/q C:\Bin\PvpServer_rd.exe
del/q C:\Bin\LogServer_rd.exe

copy/y C:\code\Server\Resource\Server\DBServerProcedure.xml C:\Bin
mkdir C:\Bin\Data\Scp\NewCsv
copy/y C:\Users\fwq\Desktop\server\Server\Data\Scp\NewCsv\*.* C:\Bin\Data\Scp\NewCsv
mkdir C:\Bin\db
copy/y C:\code\Server\Resource\Server\db\update.sql C:\Bin\db
"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:update /path:"C:\Users\fwq\Desktop\csv"  /closeonend:1
copy/y C:\Users\fwq\Desktop\csv\*.csv  C:\Users\fwq\Desktop\server\Server\Data\Scp\NewCsv
"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:commit /url:"https://bi_an/svn/p001/server/trunk/Bin" /path:"C:\Bin" /logmsg:"update run file" /closeonend:1

