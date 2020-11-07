#!/bin/bash
#迁服:
#    1.sh $0 plat gameid qianfu ip
#    2. 装服
#    3.sh $0 plat gameid restore
#    4.sh $0 plat gameid delete
#合服:
#    1.sh $0 plat gameid hefu mainip
#    2.sh $0 plat gameid main primid
#    3.sh $0 plat primid delete
serverdir=/data/server/wqyry
mydumpcmd=`which mysqldump`
mysqlcmd=`which mysql`
myconf='--defaults-extra-file=/root/.my.cnf'


function controlgame(){
ctrl=$1
ctrsh=/data/scripts/update.sh
sh $ctrsh $ctrl $gamedir
}

function backupdb(){
sh /data/scripts/dbbackup.sh $plat $gameid
if [ $? -ne 0 ];then
   echo "FUCK_ERROR:Backup $dbname failed."
   exit 113
fi
}

function rsyncfile(){
backupfile=$1
keyfile=/root/.common
[ ! -f $keyfile ] && echo "FUCK_ERROR:No key file $keyfile" && exit 110
rsyncmd=`which rsync`
if [ "x$rsyncmd" == "x" ];then
    echo "FUCK_ERROR:Rsync command not exist."
    exit 111
fi
echo "$rsyncmd $backupfile to ${mainip}:/data/tmp/"
$rsyncmd -avzP -e "ssh -o 'StrictHostKeyChecking no' -i $keyfile -p 59878" $backupfile common@${mainip}:/data/tmp/${dbname}.sql.gz  &> /dev/null
if [ $? -eq 0 ];then
   echo "Message:Backup and rsync $backupfile success."
else
   echo "FUCK_ERROR:Rsync backup file $backupfile failed."
   exit 112
fi
}

function resetsqlmod(){
truncfile=/data/scripts/truncate_table.txt
if [ -f $truncfile ];then
dos2unix $truncfile
trunclist=""
for trunctb in `cat $truncfile`;do
   if [ -z "$trunclist" ];then
      trunclist=$trunctb
   else
      trunclist="${trunclist},$trunctb"
      sed -r -i "s/(trunclist=').*[^\'](';)/\1$trunclist\2/" $resetsql
   fi
done
else
   echo "FUCK_ERROR:Not found file $truncfile"
   exit 201
fi
}

function cpbackfile(){
if [ "$action" == "qianfu" ];then
    backfile=$(ls -t /data/backup/wqyry/$plat/$dbname |head -n 1)
    rsyncfile /data/backup/wqyry/$plat/$dbname/$backfile
else
   # hefu
    mysqlmess="$myconf -t --hex-blob"
    ignoretb=/data/scripts/ignore_table.txt
    if [ -f $ignoretb ];then
        dos2unix $ignoretb
        ignortables=""
        for tbname in `cat $ignoretb`;do
           ignortables="$ignortables --ignore-table=${dbname}.$tbname"
        done
    else
        echo "FUCK_ERROR:Not found $ignoretb"
        exit 120
    fi
          #ignortables="--ignore-table=${dbname}.tb_setting --ignore-table=${dbname}.tb_player_advice --ignore-table=${dbname}.tb_database_version --ignore-table=${dbname}.tb_day_history --ignore-table=${dbname}.tb_bosschallenge --ignore-table=${dbname}.tb_festivalact --ignore-table=${dbname}.tb_forb_mac --ignore-table=${dbname}.tb_pvp_season_history --ignore-table=${dbname}.tb_redequipdraw_record --ignore-table=${dbname}.tb_worldboss"
    backfile=/data/backup/wqyry/$plat/$dbname/${dbname}.sql.gz
    $mydumpcmd $mysqlmess $dbname $ignortables |gzip >$backfile
    if [ ${PIPESTATUS[0]} -eq 0 -a ${PIPESTATUS[1]} -eq 0 ];then
        rsyncfile $backfile
    else
        echo "FUCK_ERROR:Backup cpfile failed."
        exit 113
    fi
fi
}

function resetdata(){
re=/data/scripts/wqyryreset.sql
resetsql=/tmp/${dbname}_reset.sql
\cp $re $resetsql
resetsqlmod
if [ -f $resetsql ];then
    echo "mysql source $resetsql"
    $mysqlcmd $myconf -A $dbname < $resetsql
    $mysqlcmd $myconf -A $dbname -e "CALL wqyryclean('$action');DROP PROCEDURE IF EXISTS wqyryclean;"
    if [ $? -eq 0 ];then
        echo "$dbname clean old data success."
    else
        echo "FUCK_ERROR:Excute reset sql failed."
        exit 106
    fi
else
    echo "FUCK_ERROR:$resetsql not exists."
    exit 107
fi   
}

function restoredata(){
if [ "$action" == "main" ];then
    datafile=/data/tmp/wqyry_${plat}_${primid}.sql.gz
else
    datafile=/data/tmp/${dbname}.sql.gz
fi
    
if [ ! -f $datafile ];then
   echo "FUCK_ERROR:No datafile $datafile in server."
   exit 108
fi
echo "mysql source $datafile"
datasql=$(basename $datafile .gz)
[ -f $datasql ] && rm -f $datasql
gunzip < $datafile | $mysqlcmd $myconf -A $dbname
if [ ${PIPESTATUS[0]} -ne 0 -o ${PIPESTATUS[1]} -ne 0 ];then
    echo "FUCK_ERROR:Import primary datafile $datafile failed."
    exit 109
fi

}

function mvgame(){
if [ -d $gamedir ];then
    [ -d /data/backup/movedgame ] || mkdir /data/backup/movedgame
    mv $gamedir /data/backup/movedgame/
    cd /data/backup/movedgame/
    tar czf ${gdir}.tar.gz $gdir
    if [ $? -eq 0 ];then
        rm -rf $gdir
    else
        echo "Warning:Tar moved gamedir $gdir failed."
    fi
fi
$mysqlcmd $myconf -e "drop database $dbname"
}

function cleansuper(){
[ -f /etc/supervisor/conf.d/${gdir}.ini ] && rm -f /etc/supervisor/conf.d/${gdir}.ini
supervisorctl update
}

function other(){
$mysqlcmd $myconf -A $dbname -e "update tb_merge set mergeid=$gameid,cnt=cnt+1 where srvid=$gameid or mergeid=$gameid;update tb_merge set mergeid=$gameid,cnt=cnt+1 where srvid=$primid or mergeid=$primid;"
if [ $? -eq 0 ];then
    :
else
    echo "Warning:Update ${dbname}.tb_merge failed,check and redo manual."
fi
}

function usage(){
echo -n "Usage:$0 plat gameid [hefu|qianfu|main] targetip"
}

plat=$1
gameid=$2
action=$3
dbname=wqyry_${plat}_${gameid}
gdir=${plat}_game_${gameid}
gamedir=$serverdir/${gdir}
if [ -d $gamedir ];then
    :
else
    echo "FUCK_ERROR:No game directory $gamedir"
    exit 100
fi
# stopgame
controlgame stop
if [ $# -eq 3 ];then
    if [ "$action" == "del" -o "$action" == "delete" ];then
        backupdb
        mvgame
        cleansuper
    elif [ "$action" == "restore" ];then
        controlgame stop
        restoredata
        controlgame start
    else
        echo "FUCK_ERROR:No such action $action,process stop."
        exit 101
    fi
elif [ $# -eq 4 ];then
    if [ "$action" == "hefu" ];then
        mainip=$4
        if ping -c 1 $mainip &> /dev/null;then
            :
        else
            echo "FUCK_ERROR:Can't connect server $mainip,process stop."
            exit 102
        fi
        backupdb
        resetdata
        cpbackfile
    elif [ "$action" == "qianfu" ];then
        mainip=$4
        if ping -c 1 $mainip &> /dev/null;then
            :
        else
            echo "FUCK_ERROR:Can't connect server $mainip,process stop."
            exit 103
        fi
        backupdb
        cpbackfile
    elif [ "$action" == "main" ];then
        backupdb
        shift 3
        primlist=$@
        for primid in `echo "$primlist" |tr ',' ' '`;do
            restoredata
        done
        resetdata
        other
        controlgame start
    else
        echo "FUCK_ERROR:No such action $action,process stop."
        exit 104
    fi
else
    echo "FUCK_ERROR:Lack of key paramaters,process exit."
    exit 105
fi
echo "Message:Finish."
