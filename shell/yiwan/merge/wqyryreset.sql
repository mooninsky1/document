DROP PROCEDURE IF EXISTS `wqyryclean`;
DELIMITER ;;
CREATE PROCEDURE `wqyryclean`(IN `action` varchar(10))
BEGIN
    DECLARE trunctable varchar(100);
    DECLARE trunclist text;
    DECLARE truncnum INT;
    DECLARE length1 INT;
    DECLARE length2 int;
    DECLARE trunclength INT;
    DECLARE tablename varchar(100);
    DECLARE enddel int;
    DECLARE delete_table CURSOR for select table_name from information_schema.columns where table_schema=(SELECT database()) and table_name not in('TEMP_delete_data') and table_name not in('tb_account') and column_name='charguid';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET enddel=1;
       

    SET trunclist='tb_arena,tb_arena_event,tb_arena_robot,tb_babel_rank,tb_cailiaofuben_rank,tb_cross_citywar_history,tb_crossarena_history,tb_crossarena_xiazhu,tb_crossboss_history,tb_crosstask_history,tb_dupl_rank,tb_extremity_rank,tb_group_purchase,tb_guild_citywar,tb_guild_newwar,tb_guild_palace,tb_hunlingxianyu_rank,tb_lingshoumudi_rank,tb_multi_crossboss_history,tb_new_babel_rank,tb_new_crossboss_history,tb_party_guild_duobao,tb_party_guild_purchase,tb_party_rank,tb_player_christmas_tree,tb_player_crosstask,tb_player_yiyuanduobao,tb_player_yiyuanduobao_history,tb_player_yuandan,tb_rank_arena,tb_rank_baojia,tb_rank_consumecount,tb_rank_crossscore,tb_rank_equip_power,tb_rank_extramity_monster,tb_rank_extremity_boss,tb_rank_hongyan,tb_rank_hunqi,tb_rank_jianyu,tb_rank_level,tb_rank_lingshou,tb_rank_lingzhen,tb_rank_magickey,tb_rank_minglun,tb_rank_pifeng,tb_rank_power,tb_rank_qilinbi,tb_rank_realm,tb_rank_ride,tb_rank_ride_dupl,tb_rank_ride_war,tb_rank_secret_simple,tb_rank_shenbing,tb_rank_shengqi,tb_rank_shenwu,tb_rank_tiangang,tb_rank_wing,tb_rank_xiuwei,tb_rank_zhannu,tb_shenwufb_rank,tb_sprintrank_holyshield,tb_sprintrank_hunbing,tb_sprintrank_level,tb_sprintrank_magickey,tb_sprintrank_power,tb_sprintrank_ride,tb_sprintrank_wing,tb_waterdup_rank,tb_zhuangbeifuben_rank,tb_xnhongbao';
    SET truncnum=0;
    truncloop:LOOP
        if truncnum=0 THEN
            set trunctable=SUBSTRING_INDEX(trunclist,',',truncnum+1);
        ELSE
            SET length1=LENGTH(SUBSTRING_INDEX(trunclist,',',truncnum));
            SET length2=LENGTH(SUBSTRING_INDEX(trunclist,',',truncnum+1));
            if length1=length2 THEN
                LEAVE truncloop;
            end IF;
            SET length1=length1+1;
            SET trunclength=length2-length1;
            set trunctable=SUBSTRING(SUBSTRING_INDEX(trunclist,',',truncnum+1),length1+1,trunclength);
        end if;
        set @_sql=concat('truncate table ',trunctable);
        PREPARE stmt FROM @_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET truncnum=truncnum+1;
    END LOOP truncloop;
    IF action='main' THEN
        DROP TABLE IF EXISTS TEMP_delete_data;
        CREATE TEMPORARY TABLE TEMP_delete_data(charguid bigint not null default '0' primary key);
        INSERT INTO TEMP_delete_data SELECT a.charguid  FROM tb_player_info a,tb_account b WHERE a.account_id=b.account_id AND b.last_logout<=DATE_SUB(NOW(),INTERVAL 1 MONTH) AND a.level<=90 AND a.charguid not in(SELECT role_id FROM tb_exchange_record);
        set enddel=0;
        OPEN delete_table;
        delete_cursor:LOOP
            FETCH delete_table INTO tablename;
            if enddel=1 THEN LEAVE delete_cursor; END IF;
            set @_sqldel=concat('DELETE FROM ',tablename,' WHERE charguid in (SELECT charguid FROM TEMP_delete_data)');
            PREPARE stmt2 FROM @_sqldel;
            EXECUTE stmt2;
            DEALLOCATE PREPARE stmt2;
        END LOOP delete_cursor;
        CLOSE delete_table;

        DELETE FROM tb_player_party WHERE id BETWEEN 30000000 AND 40000000;
        DELETE FROM tb_account WHERE account_id NOT IN (SELECT account_id FROM tb_player_info);
        DELETE FROM tb_relation WHERE rid in (SELECT charguid FROM TEMP_delete_data);
        update tb_player_marry_schedule set scheduleId = 0, scheduleTime = 0;
        update tb_mail_content set refflag = 2 where refflag = 1;
        replace into tb_setting  value(7,unix_timestamp(current_timestamp()));
        delete from tb_relation where relation_type=0;
    END IF;
END;
