#!/bin/sh
#1,cp exe/so file to dir
#2,start server
#3,stop server
#4,restart server
#5,upand_restart
#run it as sh $0 upand_restart /data/servers/sywz/game999
#sh $0 upand_restart /data/server/wqyry/xiyou_game_9998
#run it as sh $0 open_time  /data/servers/sywz/game999 "2017-02-07 10:00:00"
#run it as sh $0 upand_restart /data/servers/sywz
#run it as sh $0 first_start /data/servers/sywz/game1

#从本地salt key中获取所需字段
Local_Dir=/data/file
Log_Dir=/data/logs/yumwei
Log_File=$Log_Dir/$(date +%Y%m%d%H%M).log
Salt_Key=$(cat /etc/salt/minion_id)

#set -o nounset

Conf_Dir=/data/scripts
Prog_Dir=$2
Game_Path=$2
Server_Dirs=$2

PLAT=$(basename $Prog_Dir|awk -F"_" '{print $1}')
Role=$(basename $Prog_Dir|awk -F"_" '{print $2}')
NumBer=$(basename $Prog_Dir|awk -F"_" '{print $NF}')
Game_Name=$(echo $Prog_Dir|awk -F"/" '{print $(NF-1)}')
Log_Path=/data/logs/xiyou_log/$Game_Name/$PLAT
Super_Log=/data/logs/${Game_Name}${PLAT}
SuperV=/etc/supervisor/conf.d
BackDir=/data/backup/back_game
#if [ "$PLAT"x == "xiyouprex" ];then
#   Run_Dir=$(echo $Prog_Dir|sed "s/xiyoupre/xiyou/")
#else
#fi
Run_Dir=$Prog_Dir

echo $PLAT $Role $NumBer
   
if [ "$Game_Name"x == "x" -o "$Role"x == "x" ];then
   echo "FUCK_ERROR,NO game or no role"
   exit 504
fi

[ ! -d $Log_Dir ] && mkdir -p $Log_Dir
[ ! -d $BackDir ] && mkdir -p $BackDir


Base_SourceDir=/data/file/Decompres

#2019年 06月 05日 星期三 09:59:52 CST add by chenke begin
#更新时优先选择对应平台目录，没有对应平台目录且平台在ALL中则用ios目录,否则使用server目录
ALL="yueyu|xinwan|iqiyi|nextjoy|lewan|xipu|redfox|redfoxroma|oasis"
Source_Dir=$Base_SourceDir/$PLAT

function selectDir(){
    if [[ $PLAT =~ $ALL ]];then
      Source_Dir=$Base_SourceDir/ios
    else
      Source_Dir=$Base_SourceDir/server
    fi
    echo $PLAT
}

if [ ! -d $Source_Dir ];then
    selectDir
elif [ `ls -A $Source_Dir/ |wc -l` -eq 0 ];then
    selectDir
fi

echo "Source_Dir is $Source_Dir"
#2019年 06月 05日 星期三 09:59:52 CST add by chenke end#


if [ ! -d $Source_Dir ];then
   echo "FUCK_ERROR,$Source_Dir NOT EXIST"
   exit 404
fi

function Hot_Update(){
  echo "IN $0 Hot_Update rsync -av $Source_Dir/activity  $Prog_Dir/"
  if [ -d $Source_Dir/activity ]; then
    /usr/bin/rsync -av --exclude="srvconf.xml" $Source_Dir/activity  $Run_Dir
  else
    echo "FUCK_ERROR, $Source_Dir/activity NOT EXIST"
  fi
}


Delete_Files=srvconf.xml

[ "$Server_Dirs"x == "x" ] && echo "Please give directory" && exit 504
RE=$(echo $Server_Dir|awk -F"/" '{if ($NF == "")  print $2}')
if [ $RE ];then
    Server_Dir=${Server_Dirs%/*}
else
    Server_Dir=$Server_Dirs
fi

#如果目录以数字结尾则只操作些目录，否则操作之下一层目录。单服或全服操作
Num=$(echo $Server_Dir|grep -Po "\d+$")
if [ "$Num"x == "x" ];then
 Server_Dir=$(find $Server_Dir -maxdepth 1 |grep -E  "[0-9]+" )
 Num=$(echo $Server_Dir|grep -Po "\d+")
fi


function server_Update(){
  echo "IN $0 server_Update /usr/bin/rsync -av --exclude-from=/data/scripts/server.list $Source_Dir $Run_Dir"
  if [ -d $Source_Dir/activity ]; then
    /usr/bin/rsync -av --exclude-from=/data/scripts/server.list $Source_Dir/ $Run_Dir
  else
    echo "FUCK_ERROR, $Source_Dir/activity NOT EXIST"
  fi


}

#更新
function File_Rsync(){
echo "In $0 File_Rsync Rsync_Update"
#删除指定文件
for File in $Delete_Files
do
[ -f $Dir_Source/$File ] && rm -f $Dir_Source/$File
done

for Dir in $Server_Dir
do
  if [ -d $Dir ];then
       Chek_Dir=${Dir##*/}
    if [ ${Chek_Dir:0:6}x == "centerx" ];then
        ROLE=leader
    else
        ROLE=game
    fi
    echo "/usr/bin/rsync -av --exclude="srvconf.xml" $Source_Dir/ $Dir/  > $Log_File"
    /usr/bin/rsync -av --exclude="srvconf.xml" $Source_Dir/ $Dir/ 2>&1 > $Log_File
#调用api
#Back_Port=$(grep backend_port $Dir/config.properties |awk -F "=" '{print $2}')
#echo "!!!!!! $Back_Port "
#echo "http://localhost:$Back_Port/jar?param="
#curl http://localhost:$Back_Port/jar?param=
  else
     echo "此服务器未部署游戏服，退出"
  fi
done
}


function Start_Server(){
  for Dir in $Server_Dir
  do
  {
    
    T=$(awk "BEGIN{srand($RANDOM);print 5*rand()}")
    #sleep $T
    Server=${Dir##*/}
    #start order 9991 9992 9993 9994
    if [ $NumBer -gt 9991 -a $NumBer -le 9994 ];then
       T=$(awk "BEGIN{print 5*($NumBer-9990)}")
       echo "In Start_Server sleep $T s"
       sleep $T
    fi
    sh $Dir/game.sh start
  }&
  done 
  wait
  Check_Run
}

function Stop_Server(){
  for Dir in $Server_Dir
  do
  {
    T=$(awk "BEGIN{srand($RANDOM);print 5*rand()}")
    echo "In Stop_Server sleep $T s"
    sleep $T
    Server=${Dir##*/}
    echo "in $0 Stop_Server is $Server"
    sh $Dir/game.sh stop
  }&
  done 
  wait
}

function Open_Time(){
  for Dir in $Server_Dir
  do
    echo "In Open_Time"
    GameId=${Dir##*/}
    echo "Open_Time set ${OPEN_DATE} on $GameId"
    sed -i "/open_date/ c open_date=${OPEN_DATE}" $Dir/config.properties
    /usr/bin/supervisorctl restart $GameId
    cd $Dir 
    [ -f insert_dba.sh ] && sh insert_dba.sh|| echo "insert_dba.sh not exist"
  done 
}

function Hefu_Time(){
  for Dir in $Server_Dir
  do
    echo "In Hefu_Time"
    GameId=${Dir##*/}
    echo "Open_Time set ${OPEN_DATE} on $GameId"
    sed -i "/hefu_date/ c hefu_date=${HEFU_DATE}" $Dir/config.properties
  done 
}

function First_start(){
  GameName=${Server_Dirs##*/}
  /usr/bin/supervisorctl reread
  /usr/bin/supervisorctl update
  echo "In First_start sleep 8 s"
  sleep 8
  Check_Run
}

function Hefu_start(){
  /usr/bin/supervisorctl start game${Num}
  for Dir in $Server_Dir
  do
     echo "sh insert_dba.sh"
     cd $Dir
    [ -f insert_dba.sh ] && sh insert_dba.sh|| echo "insert_dba.sh not exist"
  done 
  

}

#更新nginx配置;Server_Dirs=$2
#HTML_VER=$3
#Vhost_Dir="/usr/local/nginx/conf/vhosts"

function Nginx_Update(){
  GameNumber=${Server_Dirs##*[a-z]} 
  if [ -f $Vhost_Dir/game${GameNumber}.conf ];then
    sed -r -i "s@index[0-9]+\.html@$HTML_VER@g" $Vhost_Dir/game${GameNumber}.conf
    /usr/local/nginx/sbin/nginx -s reload
   grep "$HTML_VER" $Vhost_Dir/game${GameNumber}.conf
  else
    echo "$Vhost_Dir/game${GameNumber}.conf not exist FUCK_ERROR"
    exit "404"
  fi

}

function Import_Sql(){
 sh /data/scripts/create_database.sh  $Server_Dirs sqlupdate
}

function Check_Run(){
  SuCtl=/usr/bin/supervisorctl
  $SuCtl status ${PLAT}_${Role}_${NumBer}: 2>/dev/null|awk '{++a[$2]} END { ("RUNNING" in a && length(a)==1 )? re="RUNNING ok":re="FUCK_ERROR"; print re}'
}


function BackServer_Dir(){
   echo "BackServer_Dir"
#   ServerDir=/data/server/wqyry/${PLAT}_game_${NumBer}
   ServerDir=/data/server/${Game_Name}/${PLAT}_game_${NumBer}
   if [ -d ${BackDir}/${PLAT}_game_${NumBer}.0 ];then
       /bin/rm -rf ${BackDir}/${PLAT}_game_${NumBer}.0
   fi
   if [ -d ${BackDir}/${PLAT}_game_${NumBer} ];then
       mv  ${BackDir}/${PLAT}_game_${NumBer} ${BackDir}/${PLAT}_game_${NumBer}.0
   fi
   /bin/cp -rf $ServerDir $BackDir

}

function Back_Db(){
   echo "Back_Db"
   sh $Conf_Dir/before_update_backupdb.sh ${PLAT} ${NumBer}
}

function Back_Server(){
if [ ${PLAT}x == iosx ];then
  BackServer_Dir
  Back_Db
else
   echo "not ios ,no Back_server"

fi
}
#程序开始,对目录做判断，如果目录含数字则只操作单服，否则循环操作
case $1 in
  restart)
        Stop_Server
        Start_Server
    ;;
  update)
	Hot_Update
    ;;
server_update)
       server_Update
;;
  stop)
      Stop_Server
  ;;
  start)
      Start_Server
  ;;
  upand_restart)
      Stop_Server
      Back_Server
      File_Rsync
      Start_Server
  ;;
  update_sql)
      Stop_Server
      Back_Server
      File_Rsync
      Import_Sql
      Start_Server
  ;;
  open_time)
      Open_Time
  ;;
  hefu_time)
      Hefu_Time
 ;;
  first_start)
      First_start
  ;;
  hefu_start)
      Hefu_start
  ;;
  hot_load)
        Hot_loadRes
        Hot_loadJar
    ;;
  *)
      echo "FUCK_ERROR,no arguments"
      exit 455
  ;;
esac
