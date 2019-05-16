#!/bin/bash

echo "start handle..."

#purpose:	统计在线时长最长前5等级/人数最多的前5VIP等级/统计钻石，王者，至尊VIP人数 !!!!
#date:		2019/05/16
#author:	looyer
#note: 		抽取西游 Android和IOS 30个服统计结果打包

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

sql_m1="select level, floor(online_time/(24*3600)) as nday from tb_player_info ORDER BY online_time desc limit 5;"
sql_m2="select vip_level, count(*) as num from tb_player_info GROUP BY vip_level ORDER BY count(*) desc limit 6;"
sql_m3_1="select count(*) from tb_player_vip where vip_typelasttime1 > 0;"
sql_m3_2="select count(*) from tb_player_vip where vip_typelasttime2 > 0;"
sql_m3_3="select count(*) from tb_player_vip where vip_typelasttime3 > 0;"

res_d1=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -e "${sql_m1}")
res_d2=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -e "${sql_m2}")
res_d3_1=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -N -e "${sql_m3_1}")
res_d3_2=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -N -e "${sql_m3_2}")
res_d3_3=$(mysql -u${USER} -p${PWD} -h${HOST} ${FN} -N -e "${sql_m3_3}")

echo -e "${res_d1}\n\n${res_d2}\n\n${res_d3_1} ${res_d3_2} ${res_d3_3}\n" >sci_dd_tmp.txt

echo "finish handle...ok!"
