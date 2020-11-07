echo off
echo 'update csv'
"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:update /path:"E:\server_branch\csv"  /closeonend:1
copy/y E:\server_branch\csv\*.csv  .\Server\Data\Scp\NewCsv

"C:\Program Files\TortoiseSVN\bin\TortoiseProc.exe" /command:commit  /path:".\Server\Data\Scp\NewCsv" /logmsg:"commit csv file" /closeonend:1  


pause

echo 'build rar'
WinRAR.exe a -ep1 -o+  -r  -iback   .\Server.rar  .\Server
pause