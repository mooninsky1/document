#!/bin/bash
#Template for mysql and postgres database
#rename filename GAMENAME_dbback.sh
#201803261000 v1.0
#201803261618 v1.1   添加postgres支持
#201803261618 v1.2   添加日志记录上传
#201806281011 v1.3   添加mysql blob格式支持
#201808021033 v1.4   完善getdblist模块,支持任何常规格式数据库名字格式
#201808271530 v1.5   修改mysql部分，备份输入zip直接压缩
#201808311135 v1.6   修改mysql部分，个别游戏单库备份bug
#201809261535 v1.7   curl上传返回处理
#yuwm

#其他部分 不用修改
GameName=wqyry
bktime=$(date +%Y%m%d%H%M)
GNAME=$(echo $GameName |tr 'a-z' 'A-Z')
IP=$(cat /etc/salt/minion_id |awk -F'-' '{print $NF}')
Workdir=/data/backup

function Usage(){
echo "Usage:sh $0 [plat gameid]"
exit 100
}

function mysqldb(){
if [ ! -f /root/.my.cnf ];then
   echo "FUCK_ERROR:No config file /root/.my.cnf"
   bkstat=false
   bklog
   exit 1
fi
mysqlcmd=`which mysql`
mydumpcmd=`which mysqldump`
myconf="--defaults-extra-file=/root/.my.cnf"
mysqlmess="$myconf --single-transaction -R --hex-blob"
}

function postdb(){
postcmd="/usr/local/postgres/bin/psql"
postdumpcmd=/usr/local/postgres/bin/pg_dump
postmess="-Fc -b -c -C -E UTF8 -Upostgres"
}

function getdblist(){
if [ $# -eq 0 ];then
   dbmes=".*"
elif [ $# -eq 1 ];then
   Gtype=$1
   Gameid=$1
   dbmes="[^0-9]0*${Gameid}$"
elif [ $# -eq 2 ];then
   Gtype=$1
   Gameid=$2
   dbmes="${Gtype}[^0-9]*0*${Gameid}$"
elif [ $# -eq 3 ];then
   Plat=$1
   Gtype=$2
   Gameid=$3
   dbmes="${Plat}.*${Gtype}[^0-9]*0*${Gameid}$"
else
   Usage
fi
if [ "$dbtype" == "mysql" ];then
   mysqldb
   dblist=$($mysqlcmd $myconf -N -e "show databases" |grep -Ev "schema|mysql|test|sys" |grep -Ei "$dbmes" )
else
   postdb
   dblist=$($postcmd -hlocalhost -Upostgres -t -c "select datname from pg_database where datname not like 'template%' and datname <> 'postgres';" |grep -Ei "$dbmes" |grep -v "logd" )
fi
   
}

function errormail(){
logdir=/data/logs/${GameName}bklog
[ ! -d $logdir ] && mkdir -p $logdir
MAILFILE=$logdir/${dbname}_dump.log
EMAIL=yunwei@2xi.com
echo result: $resultfull >> $MAILFILE
if [ $resultfull -eq 0 ];then
     echo "`date +'#%Y-%m-%d %H:%M:%S'`  end backup all .... success" >>$MAILFILE
else
     echo "`date +'#%Y-%m-%d %H:%M:%S'`  end backup all .... failed" >>$MAILFILE
     echo "FUCK_ERROR:${dbname} backup failed."
     curl -k -u yunwei:mail.52xiyou.com -F to=$EMAIL -F from=$GameName -F title="${GNAME}_${dbname}_$IP dump Database Error" -F content="`tail -n 3 $MAILFILE`" http://mail.52xiyou.com/sendemail.php
     exit 100
fi
}

function updatebk(){
Rsyncip=192.168.192.135
if [ -n /etc/rsync.pwd ];then
   echo bRGgKiI20tsaACd > /etc/rsync.pwd
   chmod 600 /etc/rsync.pwd
fi
key=www.52xiyou.com
Hour=`date +%H`
if [ $Hour -eq 0  -o $Hour -eq 12 -o $Hour -eq 18 ];then
   backupdir=$Workdir/upload
else
   backupdir=$Workdir/$GameName
fi
UPTYPE=$(basename $backupdir)
if [ "$UPTYPE" == "upload" ];then
   UPDIR=UPLOAD/$GNAME
else
   UPDIR=$GNAME
fi
echo "------------------rsync time $bktime----------------------" >> /tmp/curl.log
md5=$(echo -n $Rsyncip$IP${backupdir}backup@${Rsyncip}::backup/$UPDIR$key |md5sum |awk '{print $1}')
res=$(curl -k "https://yunweinew.2xi.com/game/game_back_up/?main_server_ip=$Rsyncip&server_ip=$IP&source_path=$backupdir&target_path=backup@${Rsyncip}::backup/$UPDIR&md5=$md5") 
echo $res >> /tmp/curl.log
Code=$(echo $res|awk -F',|:' '{print $2}')
if [ $Code -eq 0 ];then
   :
else
   bkstat=rsyncfalse
fi
echo "------------------end `date +"%Y%m %D %R"`----------------------" >> /tmp/curl.log
}

function mysqlbackup(){
Plat=$(cat /etc/salt/minion_id |awk -F'-' '{print $3}')
if [ "$Plat" == "hunbu" ];then
    Plat=$(echo $dbname |awk -F'_' '{print $1}')
    if [ "$Plat" == "$GameName" ];then
        Plat=$(echo $dbname |awk -F'_' '{print $2}')
    fi
fi
backdir=$Workdir/$GameName/$Plat/$dbname
uploaddir=$Workdir/upload/$Plat/$dbname
[ ! -d $backdir ] && mkdir -p $backdir
[ ! -d $uploaddir ] && mkdir -p $uploaddir
errlog=$Workdir/bkerror.log
backfile=${dbname}_${bktime}.sql.gz
$mydumpcmd $mysqlmess $dbname |gzip > $backdir/$backfile
if [ ${PIPESTATUS[0]} -eq 0 -a ${PIPESTATUS[1]} -eq 0 ] &> /dev/null;then
   resultfull=0
else
   echo "FUCK_ERROR:Backup $dbname failed."
   resultfull=1
   bkstat=false
fi
errormail
Hour=`date +%H`
if [ $Hour -eq 0  -o $Hour -eq 12 -o $Hour -eq 18 ];then
    cp $backdir/$backfile $uploaddir/
fi
}

function postbackup(){
Plat=$(cat /etc/salt/minion_id |awk -F'-' '{print $3}')
if [ "$Plat" == "hunbu" ];then
    Plat=$(echo $dbname |awk -F'_' '{print $1}')
    if [ "$Plat" == "$GameName" ];then
        Plat=$(echo $dbname |awk -F'_' '{print $2}')
    fi
fi
backdir=$Workdir/$GameName/$Plat/$dbname
uploaddir=$Workdir/upload/$Plat/$dbname
[ ! -d $backdir ] && mkdir -p $backdir
[ ! -d $uploaddir ] && mkdir -p $uploaddir
backfile=${dbname}_${bktime}.dump
$postdumpcmd $postmess -f $backdir/$backfile $dbname
resultfull=$?
if [ $resultfull -eq 0 ];then
   :
else
   echo "FUCK_ERROR:Backup $dbname failed."
   bkstat=false
fi
errormail
Hour=`date +%H`
if [ $Hour -eq 0  -o $Hour -eq 12 -o $Hour -eq 18 ];then
    cp $backdir/$backfile $uploaddir/
fi
}

function backup(){
if [ "$dbtype" == "mysql" ];then
   mysqlbackup
else
   postbackup
fi
}

function bklog(){
endbk=$(date +%Y%m%d%H%M)
backlog=/var/log/bklog.log
echo "bktype=data,ip=$IP,bktime=$bktime,endbk=$endbk,bkstat=$bkstat" >> $backlog
}

function checkdbserver(){
dbserver=$1
systemctl status $dbserver || /etc/init.d/$1 status
}


bkstat=ok
if checkdbserver mysqld &> /dev/null && checkdbserver postgresql &> /dev/null;then
   echo "FUCK_ERROR:$IP both have mysql and postgres running."
   bkstat=false
   bklog
elif checkdbserver mysqld &> /dev/null;then
   dbtype=mysql
elif checkdbserver postgresql &> /dev/null;then
   dbtype=postgres
else
   echo "FUCK_ERROR:$IP have no database running."
   bkstat=false
   bklog
   exit 2
fi
if [ $# -eq 0 ];then
   getdblist
   for dbname in `echo "$dblist"`;do
       backup
   done
   updatebk
   bklog
elif [ $# -le 3 ];then
   #gameid
   #gametype gameid
   #platname gametype gameid
   getdblist $1 $2 $3
   for dbname in `echo "$dblist"`;do
       backup
   done
else
   Usage
fi
