use master
ALTER DATABASE hygame_Region_lhf1 SET OFFLINE WITH ROLLBACK IMMEDIATE
RESTORE DATABASE hygame_Region_lhf1
FROM DISK = 'E:\sky\db_back\20200427_210345_hygame_Region_lhf1.bak'

ALTER database hygame_Region_lhf1 set online 