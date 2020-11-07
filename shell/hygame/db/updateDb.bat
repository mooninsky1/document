
set /p cmd=input yes start update:

if "%cmd%" == "yes" (

echo start updat
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_1 -f 65001 -i E:\server\game1\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_2 -f 65001 -i E:\server\game2\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_3 -f 65001 -i E:\server\game3\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_4 -f 65001 -i E:\server\game4\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_5 -f 65001 -i E:\server\game5\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_6 -f 65001 -i E:\server\game6\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_7 -f 65001 -i E:\server\game7\Server\db\update.sql
sqlcmd -S 127.0.0.1 -U sa -P z-a}6P#fNdW]k9 -d hygame_region_8 -f 65001 -i E:\server\game8\Server\db\update.sql
echo end update

)else (
	echo stop update
) 

pause