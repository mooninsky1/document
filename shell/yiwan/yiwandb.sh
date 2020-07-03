#!/bin/bash

HOSTNAME="192.168.8.33"    #数据库信息
PORT="3306"
USERNAME="root"
PASSWORD="123456"
DBNAME="hytime"         #数据库名称
#清空结果文件
echo "">result.txt
#1.魔神
# 品质SR，SSR
# 查询拥有SR，SSR的数量前10，玩家数
mosheng_SSR_id="100601,100602,100603,200601,200602,200603,200604,200605,300601,300602,300603,300604,300605,300606,300607,300608,300609,300610,300611"
mosheng_SR_id="100501,100502,100503,200501,200502,200503,200504,200505,300501,300502,300503,300504,300505,300506,300507,300508,300509,300510,300511"
#写入文件
selectSSR_sql="select charguid  from tb_player_hongyan where hongyan_id in (${mosheng_SSR_id}) into outfile './ssr.txt' "
selectSSR_sql1="select charguid  from tb_player_hongyan where hongyan_id in (${mosheng_SSR_id})  "
selectSR_sql="select charguid  from tb_player_hongyan where hongyan_id in (${mosheng_SR_id})  "

#tail -n+2 去掉表头，charguids_ssr保存角色ID
charguids_ssr=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${selectSSR_sql1}" | tail -n+2`
charguids_sr=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${selectSR_sql}" | tail -n+2`

echo "ssr 数量排名:"
echo "ssr 数量排名:">>result.txt
echo "$charguids_ssr" >charguids_ssr.txt
#统计 角色拥有魔的数量
uniq -c charguids_ssr.txt | sort -rn
uniq -c charguids_ssr.txt | sort -rn >>result.txt

echo "sr 数量排名:"
echo "sr 数量排名:">>result.txt
echo "$charguids_sr" >charguids_sr.txt
uniq -c charguids_sr.txt | sort -rn
uniq -c charguids_sr.txt | sort -rn >> result.txt

# 查询SSR魔神最高等级前3级
# 先找出最高魔神等级的前3级，然后统计每个玩家拥有的数量 按数量排序
# DISTINCT 去重复 排序 取前3
selectSSRLv_sql="select DISTINCT level from tb_player_hongyan where hongyan_id in (${mosheng_SSR_id}) ORDER BY level DESC LIMIT 3 "
selectSRLv_sql="select DISTINCT level  from tb_player_hongyan where hongyan_id in (${mosheng_SR_id}) ORDER BY level DESC LIMIT 3 "
selectSSRLv=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${selectSSRLv_sql}" | tail -n+2`
selectSRLv=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${selectSRLv_sql}"| tail -n+2 `
echo $selectSSRLv
for lv in $selectSSRLv; do
	echo SSR_level:$lv
	echo SSR_level:$lv>>result.txt
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select charguid  from tb_player_hongyan where level=$lv and hongyan_id in (${mosheng_SSR_id}) " | tail -n+2`
	echo "$result" >temp.txt
	uniq -c temp.txt | sort -rn
	uniq -c temp.txt | sort -rn >> result.txt
done

echo $selectSRLv
for lv in $selectSRLv; do
	echo SR_level:$lv
	echo SR_level:$lv>>result.txt
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select charguid  from tb_player_hongyan where level=$lv and hongyan_id in (${mosheng_SR_id}) " | tail -n+2`
	echo "$result" >temp.txt
	uniq -c temp.txt | sort -rn
	uniq -c temp.txt | sort -rn >> result.txt
done

# 查询魔神穿戴的装备，装备ID最高前100获得数量
# tb_player_equips bag=23
echo "查询魔神穿戴的装备，装备ID最高前100获得数量"
echo "查询魔神穿戴的装备，装备ID最高前100获得数量" >> result.txt
selectEquip_sql="select DISTINCT item_tid  from tb_player_equips where bag=23  ORDER BY item_tid DESC LIMIT 100 "
selectMoshengEquip=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${selectEquip_sql}" | tail -n+2`
for euipid in $selectMoshengEquip; do
	echo euipid:$euipid
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select item_tid,count(*)  from tb_player_equips where item_tid=$euipid " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done
#2.装备融合
# 取10个融合位置 等级最高前3数量	
echo "取10个融合位置 等级最高前3数量" >>result.txt
for((pos=0; pos<10; pos++)); do
	echo "融合 ${pos} 位置 等级最高前3数量"
	echo "融合 ${pos} 位置 等级最高前3数量" >>result.txt
	rongheresult=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "SELECT DISTINCT nRongHeID FROM tb_equip_pos_upstar where pos=$pos ORDER BY nRongHeID DESC LIMIT 3" | tail -n+2`
	for rongheid in $rongheresult; do
		countresult=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select nRongHeID,count(*)  from tb_equip_pos_upstar where nRongHeID=$rongheid " | tail -n+2`
		echo "$countresult" 
		echo "$countresult" >>result.txt
	done
done

#3.主角装备阶数
#	前3阶数，10件的人数，9件的人数，。。。1件的人数
# 	tb_player_extra equip_suit 前10 每一阶段人数统计
echo "主角装备阶数 前10 每一阶段人数统计"
echo "主角装备阶数 前10 每一阶段人数统计" >>result.txt
humanEquip_sql="select DISTINCT equip_suit  from tb_player_extra  ORDER BY equip_suit DESC LIMIT 10 "
selecthumanEquip=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanEquip_sql}" | tail -n+2`
for equipsuit in $selecthumanEquip; do
	echo euipid:$equipsuit
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select equip_suit,count(*)  from tb_player_extra where equip_suit=$equipsuit " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

#4.魂兵，战翼，战弩，宝甲，圣器，魂器，圣盾
#	最高三阶，每阶总人数
echo "魂兵最高三阶，每阶总人数"
echo "魂兵最高三阶，每阶总人数">>result.txt
humanShengBing_sql="select DISTINCT level  from tb_player_shengling  ORDER BY level DESC LIMIT 3 "
selecthumanShengBing=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanShengBing_sql}" | tail -n+2`
for ShengBing in $selecthumanShengBing; do
	echo ShengBingLv:$ShengBing
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_shengling where level=$ShengBing " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "战翼 最高三阶，每阶总人数"
echo "战翼 最高三阶，每阶总人数">>result.txt
humanWing_sql="select DISTINCT level  from tb_player_new_wing  ORDER BY level DESC LIMIT 3 "
selecthumanWing=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanWing_sql}" | tail -n+2`
for WingLv in $selecthumanWing; do
	echo WingLv:$WingLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_new_wing where level=$WingLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "战弩 最高三阶，每阶总人数"
echo "战弩 最高三阶，每阶总人数">>result.txt
humanZhanNu_sql="select DISTINCT level  from tb_player_zhannu  ORDER BY level DESC LIMIT 3 "
selecthumanZhanNu=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanZhanNu_sql}" | tail -n+2`
for ZhanNuLv in $selecthumanZhanNu; do
	echo ZhanNuLv:$ZhanNuLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_zhannu where level=$ZhanNuLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "宝甲 最高三阶，每阶总人数"
echo "宝甲 最高三阶，每阶总人数">>result.txt
humanBaojia_sql="select DISTINCT level  from tb_player_baojia  ORDER BY level DESC LIMIT 3 "
selecthumanBaojia=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanBaojia_sql}" | tail -n+2`
for BaojiaLv in $selecthumanBaojia; do
	echo BaojiaLv:$BaojiaLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_baojia where level=$BaojiaLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "圣器 最高三阶，每阶总人数"
echo "圣器 最高三阶，每阶总人数">>result.txt
humanShengQi_sql="select DISTINCT level  from tb_player_shengqi  ORDER BY level DESC LIMIT 3 "
selecthumanShengQi=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanShengQi_sql}" | tail -n+2`
for ShengQiLv in $selecthumanShengQi; do
	echo ShengQiLv:$ShengQiLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_shengqi where level=$ShengQiLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "魂器 最高三阶，每阶总人数"
echo "魂器 最高三阶，每阶总人数">>result.txt
humanHunQi_sql="select DISTINCT level  from tb_player_hunqi  ORDER BY level DESC LIMIT 3 "
selecthumanHunQi=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanHunQi_sql}" | tail -n+2`
for HunQiLv in $selecthumanHunQi; do
	echo HunQiLv:$HunQiLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_hunqi where level=$HunQiLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

echo "圣盾 最高三阶，每阶总人数"
echo "圣盾 最高三阶，每阶总人数">>result.txt
humanPiFeng_sql="select DISTINCT level  from tb_player_pifeng  ORDER BY level DESC LIMIT 3 "
selecthumanPiFeng=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${humanPiFeng_sql}" | tail -n+2`
for PiFengLv in $selecthumanPiFeng; do
	echo PiFengLv:$PiFengLv
	result=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select level,count(*)  from tb_player_pifeng where level=$PiFengLv " | tail -n+2`
	echo "$result" 
	echo "$result" >>result.txt
done

#5.装备升星
# 取10个 升星位置 等级最高前3数量	
echo "取10个 升星位置 等级最高前3数量" >>result.txt
for((pos=0; pos<10; pos++)); do
	echo "升星位置 ${pos} 位置 等级最高前3数量"
	echo "升星位置 ${pos} 位置 等级最高前3数量" >>result.txt
	starlevelresult=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "SELECT DISTINCT starlevel FROM tb_equip_pos_upstar where pos=$pos ORDER BY starlevel DESC LIMIT 3" | tail -n+2`
	for starlevel in $starlevelresult; do
		countresult=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "select starlevel,count(*)  from tb_equip_pos_upstar where starlevel=$starlevel " | tail -n+2`
		echo "$countresult" 
		echo "$countresult" >>result.txt
	done
done

#清除临时文件
rm -f charguids_sr.txt charguids_ssr.txt temp.txt
