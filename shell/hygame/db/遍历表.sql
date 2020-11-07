
--EXEC master..xp_cmdshell 'bcp "SELECT * FROM [alarm].[dbo].[a_abc]" queryout "c:\book1.xls" -c -S"ip地址" -U"用户名" -P"密码"'
-- 声明变量 必须加个begin end go 包起来否则提示要申明标量变量
BEGIN 
DECLARE @tablename AS NVARCHAR(256);
DECLARE @str nvarchar(256);
-- 声明游标
DECLARE table_cur CURSOR FAST_FORWARD FOR
	SELECT sys.tables.name as TableName from sys.tables;
	
OPEN table_cur;

-- 取第一条记录
FETCH NEXT FROM table_cur INTO @tablename;


WHILE @@FETCH_STATUS=0
BEGIN
    -- 操作
	SET @str = 'bcp "SELECT * FROM tablename" queryout "d:\tablename.txt" -T -c -C 65001';
	SET @str = REPLACE(@str, 'tablename', @tablename);
    exec master..xp_cmdshell @str
    -- 取下一条记录
    FETCH NEXT FROM table_cur INTO @tablename;
END

-- 关闭游标
CLOSE table_cur;

-- 释放游标
DEALLOCATE table_cur;
END
GO