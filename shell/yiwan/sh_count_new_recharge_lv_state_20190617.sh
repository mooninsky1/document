#!/bin/bash

echo "start handle..."

#purpose:	1.未充值玩家每级人数，2.低于2000元每级人数，3.超过含2000元每级人数
#date:		2019/06/17
#author:	looyer
#note: 		抽取西游IOS开服1个月内随机5个服

rm -rf sci_tmp_xx.txt
rm -rf sci_dd_tmp.txt

echo $(grep "dbname" ./srvconf.xml) >sci_tmp_xx.txt

FN=$(awk -v RS="</*dbname>" 'NR==2{print}' sci_tmp_xx.txt)

echo $(grep "user" ./srvconf.xml) >sci_tmp_xx.txt

USER=$(awk -v RS="</*user>" 'NR==2{print}' sci_tmp_xx.txt)

echo $(grep "pwd" ./srvconf.xml) >sci_tmp_xx.txt

PWD=$(awk -v RS="</*pwd>" 'NR==2{print}' sci_tmp_xx.txt)

echo $(grep "host" ./srvconf.xml) >sci_tmp_xx.txt

HOST=$(awk -v RS="</*host>" 'NR==2{print}' sci_tmp_xx.txt)

rm -rf sci_tmp_xx.txt

echo "!FN:${FN} USER:${USER} PWD:${PWD}!"

sql_m1="select level, count(*) from (select charguid, level, ifnull((select sum(money) from tb_exchange_record where tb_exchange_record.role_id = tb_player_info.charguid), 0) as rmb from tb_player_info) ttmmpp where rmb = 0 group by level order by level;"
sql_m2="select level, count(*) from (select charguid, level, ifnull((select sum(money) from tb_exchange_record where tb_exchange_record.role_id = tb_player_info.charguid), 0) as rmb from tb_player_info) ttmmpp where rmb > 0 and rmb < 200000 group by level order by level;"
sql_m3="select level, count(*) from (select charguid, level, ifnull((select sum(money) from tb_exchange_record where tb_exchange_record.role_id = tb_player_info.charguid), 0) as rmb from tb_player_info) ttmmpp where rmb >= 200000 group by level order by level;"

res_d1=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -e "${sql_m1}")
res_d2=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -e "${sql_m2}")
res_d3=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -e "${sql_m3}")

echo -e "${res_d1}\n\n${res_d2}\n\n${res_d3}\n" >sci_dd_tmp.txt
