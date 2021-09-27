#!/bin/bash

HOSTNAME="127.0.0.1"    #数据库信息
PORT="3306"
USERNAME="root"
PASSWORD="hwc123ABC"
DBNAME="gm_operate_log"         #数据库名称


gm_add_sql = "insert into  gm_usr_list(gm_name,pass,stat,level,LastLoginTime,CreateTime,LastTime) values('gmsunjiayang','Minisunjiayangnn456',1,1,now(),now(),now())"

cmd=`mysql -h${HOSTNAME}  -P${PORT}  -u${USERNAME} -p${PASSWORD} ${DBNAME} -e "${gm_add_sql}" `

echo $cmd