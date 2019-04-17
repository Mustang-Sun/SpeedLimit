#!/bin/bash
##给192.168.0网段的IP做限速
##limit target : 192.168.0.xxx 

##网卡
## use ifconfig command to figure out you device name,here is mime,enp1s0,which usually is a default name on Centos.
DEV=enp1s0
start() {
## 清除 eth1 eth0 所有队列规则
## clean all rules on this MAC
tc qdisc del dev $DEV root 2>/dev/null

##定义总的上下带宽
## set a peak download bandwith
tc qdisc add dev $DEV root handle 2: htb
tc class add dev $DEV parent 2: classid 2:1 htb rate 3000kbit

#from 2 to 253
for (( i=2; i<=253; i=i+1 ))
do
#####下载控制在每人实际最大???k/S左右
##### value after ceil is the limit speed,3mbit approx equals 380 kb/s 
tc class add dev $DEV parent 2:1 classid 2:2$i htb rate 500kbit ceil 3mbit burst 20k
tc qdisc add dev $DEV parent 2:2$i handle 2$i: sfq
tc filter add dev $DEV parent 2:0 protocol ip prio 4 u32 match ip dst 192.168.0.$i flowid 2:2$i
 
iptables -t mangle -A PREROUTING -s 192.168.0.$i -j MARK --set-mark 0x$i
done

}
stop(){
echo -n "(删除所有队列/Deled all rules successfully ......)"
( tc qdisc del dev $DEV root &&
for (( i=2; i<=253; i=i+1 ))
do
/sbin/iptables -t mangle -D PREROUTING -s 192.168.0.$i -j MARK --set-mark 0x$i
done && echo "ok.删除成功/Delete succecced!" ) || echo "error."
}
#显示状态
status() {
echo "1.show qdisc $DEV  (显示下行队列/Download rules as bellow):----------------------------------------------"
tc -s qdisc show dev $DEV
echo "2.show class $DEV  (显示下行分类/Download classify as bellow):----------------------------------------------"
tc class show dev $DEV
echo "3. tc -s class show dev $IN (显示上行队列和分类流量详细信息/Upload Specification as bellow:):------------------"
#tc -s class show dev $IN
echo "说明:设置总队列下行和上行带宽 3M."
}
#显示帮助
usage() {
echo "使用方法(usage): `basename $0` [start | stop | restart | status ]"
echo "参数作用:"
echo "start   开始流量控制"
echo "stop    停止流量控制"
echo "restart 重启流量控制"
echo "status  显示队列流量"
}
case "$1" in
start)
( start && echo "开始流量控制! TC started!" ) || echo "error."
exit 0
;;

stop)
( stop && echo "停止流量控制! TC stopped!" ) || echo "error."
exit 0
;;
restart)
stop
start
echo "流量控制规则重新装载!/Reload!"
;;
status)
status
;;

*) usage
exit 1
;;
esac
