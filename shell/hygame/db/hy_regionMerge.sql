
if exists(SELECT * FROM SYSOBJECTS WHERE NAME='GetTableCols')
DROP PROCEDURE [dbo].[GetTableCols];

GO
CREATE  PROCEDURE [dbo].[GetTableCols]( 
@tablename VARCHAR(512),
@colStr NVARCHAR(max) OUTPUT
)
AS
BEGIN
	DECLARE @str nvarchar(256);

	SET @colStr = 'DECLARE cur_col CURSOR FOR SELECT a.[name] FROM [syscolumns] a, [sysobjects] b 
			WHERE a.[id]=b.[id] AND b.[type] = ''u'' AND b.[name]=''' + @tablename + ''' ORDER BY a.[colid] ';

	EXEC sp_executesql @colStr

	SET @colStr = '';
	OPEN cur_col
	FETCH NEXT FROM cur_col INTO @str 
	
	WHILE @@FETCH_STATUS = 0   
	BEGIN
		SET @colStr = @colStr + ',['+ @str + ']';

		FETCH NEXT FROM cur_col INTO @str 
	END
	SET @colStr = STUFF(@colStr, 1, 1, '');

	CLOSE cur_col;
	DEALLOCATE cur_col;

	return;
END

GO
if exists(SELECT * FROM SYSOBJECTS WHERE NAME='procMergeTabel')
DROP PROCEDURE [dbo].[procMergeTabel];
GO
CREATE PROCEDURE [dbo].[procMergeTabel]
@destDB varchar(64),
@TableName  NVARCHAR(255),
@step INT,
@curStep INT
AS
BEGIN
	-- 查询字段名
	DECLARE @str NVARCHAR(MAX);
	DECLARE @isql NVARCHAR(MAX);
	DECLARE @msg VARCHAR(2048);
	EXEC dbo.gettablecols @TableName,@str output;
	SET @str = LOWER(@str);
	
	SET @isql = 'INSERT INTO #destDB#.dbo.#table#(' + @str + ') ';
	SET @isql = REPLACE(@isql, '#destDB#', @destDB);
	SET @isql = REPLACE(@isql, '#table#', @TableName);
	
	SET @str = REPLACE(@str, '[', 'a.[');
	
	SET @isql = @isql + ' SELECT ' + @str + ' FROM '+@TableName+' a';
			
	EXEC(@isql)
	
	SET @msg =  'insert data into [' + @destDB + '.'+@TableName+'] done!'
	INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
	RETURN 0;
END;
----------------------------------------------------------------------------------
GO
if exists(SELECT * FROM SYSOBJECTS WHERE NAME='procMergeDB')
DROP PROCEDURE [dbo].[procMergeDB];
GO
CREATE PROCEDURE [dbo].[procMergeDB]
  @destDB AS varchar(64), 
  @loginDB AS varchar(64)
AS
BEGIN

	DECLARE @step INT;
	DECLARE @curStep INT;
	DECLARE @msg VARCHAR(2048);
	DECLARE @sql NVARCHAR(MAX);
	
	DECLARE @strAct1 VARCHAR(32);
	DECLARE @strAct2 VARCHAR(32);
	DECLARE @corpsid INT;
	DECLARE @currRank INT;		-- 合并竞技场用
	
	DECLARE @str NVARCHAR(MAX);
	DECLARE @isql NVARCHAR(MAX);

	SET @step = 0;
	SET @curStep = 0;
	
	SET @str = ''
	SET @isql = ''

BEGIN TRY

	BEGIN TRANSACTION
	-- 建立日志表
	IF EXISTS (select * from sysobjects where id =OBJECT_ID(N'dbo.merge_log') and OBJECTPROPERTY(id,N'IsUserTable')=1)
	BEGIN
		SELECT @curStep = ISNULL(max(step), 0) + 1 from dbo.merge_log where state=0;
		SET @msg = 'beginning...  current step('+CONVERT(VARCHAR(8),@curStep)+')'; 
	END
	ELSE
	BEGIN
		CREATE TABLE merge_log(step INT, state INT, createTime DATETIME, errorMsg  VARCHAR(2048) );

		SET @msg = 'beginning...  create table [merge_log] done! current step(0)'; 
		SET @curStep = 0;
	END

	PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
	INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(0, 0, GETDATE(), @msg);
	COMMIT TRANSACTION
	IF @curStep = 0
	BEGIN
		SET @curStep = 1;
	END
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'

	---------------------------------------------------
--1 拉取login对应关系表  新id可能和旧id重叠， 更新id的时候可能会有主键冲突，所以需要先删除主键再更新
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		IF LEN(@loginDB) = 0
		BEGIN
			SET @msg = 'no login db, create table [actorid_trans] ignore '
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT * FROM sysobjects WHERE id =OBJECT_ID(N'dbo.actorid_trans') AND OBJECTPROPERTY(id,N'IsUserTable')=1)
			BEGIN
				DROP TABLE dbo.actorid_trans;
			END

			SET @sql = 'SELECT a.ActorID actorid, dbo.getactorid(b.newUserid, dbo.gethigh(a.actorid)) newActorid 
							INTO actorid_trans FROM actor a LEFT JOIN #loginDB#.dbo.account_merge b 
							ON dbo.getlow(a.actorid) = b.userid';
			SET @sql = REPLACE(@sql, '#loginDB#', @loginDB);
			EXEC(@sql);

			-- 检查是不是actorid 都有对应的
			SELECT @currRank = COUNT(1) FROM actorid_trans WHERE newActorid IS NULL;
			IF @currRank != 0
			BEGIN
				SET @msg = 'table[actorid_trans] has NULL newActorid rows '
				PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
				INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, -2, GETDATE(), @msg);
				COMMIT TRANSACTION;
				RETURN;
			END

			CREATE CLUSTERED INDEX idx_actorid_trans_id on dbo.actorid_trans(actorid);
			SET @msg = 'create table [actorid_trans] done!'
		END
		
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	---------------------------------------------------
--2 角色重名  nickname为空的
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		IF EXISTS (SELECT * FROM sysobjects WHERE id =OBJECT_ID(N'dbo.actor_repeated_names') AND OBJECTPROPERTY(id,N'IsUserTable')=1)
		BEGIN
			DROP TABLE dbo.actor_repeated_names;
		END

		SET @sql = 'SELECT a.ActorID actoridL, b.ActorID actoridR, a.NickName INTO actor_repeated_names 
				FROM actor a JOIN  [#destDB#].dbo.actor b 
				ON a.NickName collate Chinese_PRC_CS_AS_KS = b.NickName AND a.NickName != '''' AND b.NickName != '''' AND a.NewActor != 1 AND b.NewActor != 1 ';	-- 区分大小写
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);

		SET @msg = 'create table [actor_repeated_names] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'



	---------------------------------------------------
--3 检查名字是否可以用actorid做名字, 用户自己取名不能取数字的
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		--DECLARE @strAct1 VARCHAR(32);
		--DECLARE @strAct2 VARCHAR(32);
		SELECT @strAct1=convert(varchar(32),max(actoridL)) , @strAct2=convert(varchar(32),max(actoridR)) FROM actor_repeated_names;
		IF LEN(@strAct1) > 15
		BEGIN
			SET @sql = 'table [actor_repeated_names] max actoridL[' + @strAct1 + '] len[' + convert(varchar(32), len(@strAct1)) + ']'; 
			PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
			INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, -1, GETDATE(), @msg);
			ROLLBACK TRANSACTION
			RETURN
		END

		IF len(@strAct2) > 15
		BEGIN
			SET @sql = 'table [actor_repeated_names] max actoridR[' + @strAct2 + '] len[' + convert(varchar(32), len(@strAct2)) + ']'; 
			PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
			INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, -1, GETDATE(), @msg);
			ROLLBACK TRANSACTION
			RETURN
		END
		

		SET @msg = 'check actorid as nickname done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'

	-- 插入数据
	---------------------------------------------------
	--4 actor
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		-- 查询字段名
		EXEC dbo.gettablecols 'actor',@str output;
		SET @str = LOWER(@str);
		SET @isql = 'INSERT INTO #destDB#.dbo.actor(' + @str + ') ';
		SET @isql = REPLACE(@isql, '#destDB#', @destDB);

		SET @str = REPLACE(@str, '[', 'a.[');

		IF LEN(@loginDB) != 0
		BEGIN
			SET @str = REPLACE(@str, 'a.[actorid]', '(SELECT TOP 1 b.[newActorid] FROM actorid_trans AS b WHERE a.ActorID = b.actorid)');	-- actorid 
			SET @str = REPLACE(@str, 'a.[practicehelper]', '(SELECT TOP 1 b.[newActorid] FROM actorid_trans AS b WHERE a.practicehelper = b.actorid)');	-- practicehelper 
			SET @str = REPLACE(@str, 'a.[practicemarauder1]', '(SELECT TOP 1 b.[newActorid] FROM actorid_trans AS b WHERE a.practicemarauder1 = b.actorid)');	-- practicemarauder1 
			SET @str = REPLACE(@str, 'a.[practicemarauder2]', '(SELECT TOP 1 b.[newActorid] FROM actorid_trans AS b WHERE a.practicemarauder2 = b.actorid)');	-- practicemarauder2 
			SET @str = REPLACE(@str, 'a.[practicemarauder3]', '(SELECT TOP 1 b.[newActorid] FROM actorid_trans AS b WHERE a.practicemarauder3 = b.actorid)');	-- practicemarauder3 
		END
		
		SET @str = REPLACE(@str, 'a.[nickname]', 'ISNULL((SELECT TOP 1 CONVERT(VARCHAR(16), a.ActorID) FROM actor_repeated_names AS c WHERE a.actorid = c.actoridL), a.[NICKNAME])');	-- actorid 
		SET @str = REPLACE(@str, 'a.[societyid]', '(SELECT TOP 1 b.[newCorpsId] FROM corpsid_trans AS b WHERE a.societyid = b.corpsId)');
		
		SET @isql = @isql + ' SELECT ' + @str + ' FROM actor a';
		
		EXEC(@isql)
		
		SET @msg =  'insert data into [' + @destDB + '.dbo.actor] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	-----------------------------------------------------
	--5 tPet
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tPet',@step,@curStep
		SET @msg =  'insert data into [' + @destDB + '.'+'tPet'+'] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'

	-----------------------------------------------------
	--6 item
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'item',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	-----------------------------------------------------
	--7 mail
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'mail',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	-----------------------------------------------------
	--8 pay
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		-- 查询字段名
		EXEC dbo.gettablecols 'pay',@str output;
		SET @str = LOWER(@str);
		-- id为自增字段
		SET @str = REPLACE(@str, ',[id]', '');
		SET @str = REPLACE(@str, '[id],', '');
		
		SET @isql = 'INSERT INTO #destDB#.dbo.pay(' + @str + ') ';
		SET @isql = REPLACE(@isql, '#destDB#', @destDB);
		
		SET @str = REPLACE(@str, '[', 'a.[');
		
		IF LEN(@loginDB) != 0
		BEGIN
			SET @str = REPLACE(@str, 'a.[actorid]', '(SELECT top 1 b.[newActorid] FROM actorid_trans AS b WHERE a.actorid = b.actorid)');
		END
		
		SET @isql = @isql + ' SELECT ' + @str + ' FROM pay a';
		
		EXEC(@isql)
		
		SET @msg =  'insert data into [' + @destDB + '.dbo.pay] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'

	-----------------------------------------------------
	--9 shop
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'shop',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	-----------------------------------------------------
	--10 task
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'task',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'
	
	
	---------------------------------------------
	--11 ActivityPersonData
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'ActivityPersonData',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'
	
	---------------------------------------------
	--12 actorlog
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'actorlog',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'
	
	---------------------------------------------
	--13 BattleMap
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'BattleMap',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'
	
	---------------------------------------------
	--14 buffer
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'buffer',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------
	--15 clan
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'clan',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------
	--16 danyao
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'danyao',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------
	--17 gongfa
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'gongfa',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------
	--18 homepageData
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'homepageData',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------
	--19 house
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'house',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------	
	--20 Item
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'Item',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------		
	--21 LingBao
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'LingBao',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------		
	--22 LingBaoFaZhen
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'LingBaoFaZhen',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------	
	--23 linggen
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'linggen',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------	
	--24 t_FeiShengData
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'t_FeiShengData',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------	
	--25 tActorBaiLian
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorBaiLian',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	
	----------------------------------------------	
	--26 tActorPlant
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorPlant',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------
	--27 tActorQiYu
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorQiYu',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--28 tActorQiYuLog
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorQiYuLog',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--29 tActorSevenDay
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorSevenDay',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--30 tActorShiLi
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorShiLi',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--31 tActorShiLiLog
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorShiLiLog',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------		
	--32 tActorSmallWorld
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorSmallWorld',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--33 tActorSmallWorldItem
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tActorSmallWorldItem',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--34 tDaDao
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tDaDao',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--35 tJiangShen
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tJiangShen',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------
	--36 tJiangShenData
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tJiangShenData',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------
	--37 tPersonPetModule
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tPersonPetModule',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------		
	--38 tSect
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		EXEC dbo.procMergeTabel @destDB,'tSect',@step,@curStep
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	----------------------------------------------	
	--15 合并竞技场
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		IF EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'dbo.Billboard_merge') AND OBJECTPROPERTY(id,N'IsUserTable')=1)
		BEGIN
			DROP TABLE dbo.Billboard_merge;
		END

		-- 查询字段名
		EXEC dbo.gettablecols 'Billboard',@str output;
		SET @str = LOWER(@str);
		
		SELECT b.arenaTopRank, a.* into Billboard_merge FROM Billboard a JOIN actor b ON a.EntityDBId=b.ActorID;
		IF LEN(@loginDB) != 0
		BEGIN
			MERGE INTO Billboard_merge AS a USING actorid_trans AS b ON a.EntityDBId = b.actorid
					WHEN MATCHED THEN UPDATE SET a.EntityDBId = b.newActorid;
		END
		
		SET @sql = 'MERGE INTO Billboard_merge AS a USING  
			(SELECT b.arenaTopRank, a.*  FROM #destDB#.dbo.Billboard a JOIN #destDB#.dbo.actor b on a.EntityDBId=b.ActorID) AS c
			ON a.EntityDBId=c.EntityDBId AND a.id=c.id
			WHEN NOT MATCHED THEN INSERT(arenaTopRank, id, orderkey, entitydbid, iconresid, [desc], extendparam1,extendparam2,rank) 
			VALUES( c.arenaTopRank, c.id, c.orderkey, c.entitydbid, c.iconresid, c.[desc], c.extendparam1,c.extendparam2,c.rank);';
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);

		ALTER TABLE Billboard_merge  ADD newRank int;
		UPDATE Billboard_merge SET newRank=arenatoprank ;
		
		--重命名
		MERGE INTO Billboard_merge a USING actor_repeated_names b
			ON a.EntityDBId=b.actoridL 
			WHEN MATCHED THEN UPDATE SET a.[desc] = CONVERT(VARCHAR(16), a.EntityDBId);

		MERGE INTO Billboard_merge a USING actor_repeated_names b
			ON a.EntityDBId=b.actoridR 
			WHEN MATCHED THEN UPDATE SET a.[desc] = CONVERT(VARCHAR(16), a.EntityDBId);
		

		--思路： 设置排名为最高排名，然后1-5000 循环 每个排名留最高等级那个，然后这个排名上的人排名加1再循环
		SET @currRank = 1;
		WHILE @currRank < 5001
		BEGIN
 			UPDATE Billboard_merge SET newRank = newRank + 1 WHERE newRank = @currRank 
				AND entityDBID != (SELECT top 1 entityDBID FROM Billboard_merge WHERE newRank=@currRank ORDER BY extendparam1 desc, arenatoprank);

				SET @currRank = @currRank + 1;
		END	--end while

		SET @sql = 'DELETE FROM #destDB#.dbo.billboard';
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);
		
		SET @sql = 'MERGE INTO #destDB#.dbo.Billboard AS a USING (select * from billboard_merge where newRank > 0 AND newRank < 5001) AS b
			ON a.id=b.id AND a.rank=b.newRank
			WHEN NOT MATCHED THEN INSERT(id, orderkey, entitydbid, iconresid, [desc], extendparam1,extendparam2,rank) 
			VALUES(b.id, b.newRank, b.entitydbid, b.iconresid, b.[desc], b.extendparam1,b.extendparam2,b.newRank);';
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);
		
		SET @msg = 'merge data into [' + @destDB + '.dbo.Billboard] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'	
	

	-------数据合并结束
	
	
	
	
	--角色改名	actor
	-----------------------------------------------------
	--actor
	--Billboard
	
	--16 @destDB.dbo.actor
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		SET @sql = 'MERGE INTO #destDB#.dbo.actor AS a USING actor_repeated_names AS b ON a.actorid = b.actoridR
					WHEN MATCHED THEN UPDATE SET a.NickName = CONVERT(VARCHAR(16), a.ActorID);';
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);
		
		SET @msg = 'transform nickname for [' + @destDB + '.dbo.actor] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'


	-----------------------------------------------------
	--17 @destDB.dbo.Billboard
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		SET @sql = 'MERGE INTO #destDB#.dbo.Billboard AS a USING actor_repeated_names AS b ON a.EntityDBId = b.actoridR
					WHEN MATCHED THEN UPDATE SET a.[Desc] = CONVERT(VARCHAR(16), a.EntityDBId);';
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);
		
		SET @msg = 'transform nickname for [' + @destDB + '.dbo.Billboard] done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'




	
	--18 清理一些表
	BEGIN TRANSACTION
	SET @step = @step + 1;
	IF @curStep = @step
	BEGIN
		SET @sql = 'TRUNCATE TABLE #destDB#.dbo.slotBillboard;
					TRUNCATE TABLE #destDB#.dbo.tPlant;
					TRUNCATE TABLE #destDB#.dbo.tShiLi;
					TRUNCATE TABLE #destDB#.dbo.tShiLiMap;
					TRUNCATE TABLE #destDB#.dbo.tShiLiOfficial;';
			
		SET @sql = REPLACE(@sql, '#destDB#', @destDB);
		EXEC(@sql);
		
		SET @msg = 'truncate table done!'
		PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']:' + @msg;
		INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
		
		SET @curStep = @curStep + 1;
	END

	COMMIT TRANSACTION
	PRINT 'STEP['+CONVERT(VARCHAR(8),@step)+'] CURSTEP['+CONVERT(VARCHAR(8),@curStep)+']'
	
	

	
	
	BEGIN TRANSACTION
	SET @msg = 'well done !!!';
	PRINT @msg;
	INSERT INTO merge_log(step, state, createTime, errormsg) VALUES(@curStep, 0, GETDATE(), @msg);
	COMMIT TRANSACTION
	
END TRY


BEGIN CATCH
	ROLLBACK TRANSACTION;
	SET @msg = 'LINE[' + CONVERT(VARCHAR(8),ERROR_LINE()) + '],ERROR[' 
				+ CONVERT(VARCHAR(8),ERROR_NUMBER()) +'],MSG['+SUBSTRING(ERROR_MESSAGE(),0,5000)+']'
	PRINT 'step['+CONVERT(VARCHAR(8),@curStep)+']: ' + @msg;
	insert into merge_log(step, state, createTime, errormsg) values(@curStep, -1, GETDATE(), @msg);
	RETURN
END CATCH

END
