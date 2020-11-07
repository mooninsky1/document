
use master
declare @ls_time varchar(100)
declare @db_file_name varchar(100)
declare @db_name varchar(100)
declare @path varchar(100)

declare	@db_base_name varchar(100)
declare	@zoneid1 int
declare	@zoneid2 int


set @ls_time = convert(varchar, getdate(), 112) + '_' + replace(convert(varchar, getdate(), 108), ':', '-')
set @db_base_name='hygame_region_'
set @zoneid1=1
set @zoneid2=8
set @path='E:\db_bak\db\'


while @zoneid1 <= @zoneid2
BEGIN
	set @db_name=@db_base_name+convert(varchar, @zoneid1, 112)
	set @db_file_name = @path + @ls_time + '_'+@db_name+'.bak'
	
	BACKUP DATABASE @db_name TO disk = @db_file_name
	set @zoneid1=@zoneid1+1
END
