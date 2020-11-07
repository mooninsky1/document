#!/bin/bash
if [ $# -ne 2 ]; then
	echo "请指定时间段"
else
	echo "时间段：$1 到 $2"
fi

var1=$1
var2=$2
cat act.log*|grep giftmoney_buy |grep "itemid=92" |awk -v awk_var1=$var1 -v awk_var2=$var2 -F '&|=' '{if($16 >= awk_var1 && $16 <= awk_var2) print $3,$4,$5,$6,$7,$8,$11,$12,$14,$15,$16,$17,$18,$19,$20,$29,$30}' >> out.txt

