#!/bin/bash
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#  > Author: zhangzhiquan
#  > Mail  : zhangzq_job@163.com 191550636@qq.com
#  > Gmail : zw231212@gmail.com
#  > Web   : https://github.com/zw231212/aw2sql
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

echo "aw2sql.sh:=========================================="

#读取配置文件信息
while read line;do
  eval "$line"
done < "conf/aw2sql.conf"
#打印配置文件的信息
echo "awstats results data dir: $DataDir"
echo "=database infomation: "
echo "host: $dbhost"
echo "port: $dbport"
echo "user: $dbuser"
echo "pass: $dbpass"

#查看文件是否存在
if [ ! -d $DataDir ];then
	echo "$DataDir is not existed!"
	exit 0
fi

fileInfoArr=[]
#获取全部的文件,一定要有外面的括号
files=($(ls $DataDir))
echo ${#files[@]}
#=======================
#文件名格式：awstats122017.share.com.txt
#也就是awstats+月份+年份+config.txt
#其中前面的是固定的，也就是月份不足2位的由0补足，然后和最后txt中间的就是config的名称；
#==========================
for index in ${!files[@]}; do
	filename=${files[$index]}
	#转换为数组
	info=(${filename//./ })
	fileInfoArr[$index]=${info[@]}
done

#echo ${fileInfoArr[45]}
#ninfo=(${fileInfoArr[45]})
#echo ${!ninfo[@]}
echo "文件个数是："${#fileInfoArr[@]}
fileStorageInfo=[]
configs=[]
confIndex=0
for index in ${!fileInfoArr[@]};do
	nthInfo=(${fileInfoArr[$index]})
	##减去2是因为不包括最后的元素，同时下标是从0开始
	end=$[${#nthInfo[@]}-2]
	configArr=${nthInfo[@]:1:$end}
	configName=${configArr// /.} #一开始我们以.来分割，这里便以.来join
	if ! [[ "${configs[@]}" =~ $configName ]];then
		configs[$confIndex]=$configName
		confIndex=$[confIndex+1]
	fi
done




