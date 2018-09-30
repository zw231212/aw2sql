#!/bin/bash
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#  > Author: zhangzhiquan
#  > Mail  : zhangzq_job@163.com 191550636@qq.com
#  > Gmail : zw231212@gmail.com
#  > Web   : https://github.com/zw231212/aw2sql
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

echo "========================================================"
echo "aw2sql.sh基本输出:"

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
echo "logSuffix: $logSuffix"
echo "------------------------------------------------------"
#查看awstats结果文件目录是否存在,以及检查是否存在文件
fileNums=$(ls $DataDir | wc -l)
if [ ! -d $DataDir -o $fileNums -le 0 ];then
	echo "$DataDir is not existed!"
	exit 0
fi

declare -A logsDateDic
declare -A logsNumDic
logsDateDic=()
logsNumDic=()
#############
# FUNCTIONS #
#############

#====================================
#fuc name: hput
#descr: 往字典里面添加数据
#param: 输入第一个是字典名称，第二个是key值 第三个是value值
#return: None
#====================================
hput() {
    eval "$1"["$2"]="$3"
}

#====================================
#fuc name: hput
#descr: 从字典里面拿数据
#param: 输入第一个是字典名称，第二个是key值
#return: None
#=====================================
hget() {
	eval echo '${'"$1[$2]"'#hash}'
}

#=====================================
#fuc name: getFlogNum
#descr: 根据config名称来获取日志文件数量，如果一个config的配置包含在另外一个config中，那么统计的数量会有错误；
#如果在config后面再添加文件的后缀了这样就会不好不一样了?这里的结果有数量限制。
#param: 输入第一个是目标目录的地址，第二个是config的名称 第三个是文件的后缀名
#return: 返回符合条件的日志的个数
#=====================================
function getFlogNum(){
	fnum=$(ls $1 | grep "$2.$3" | wc -l)
	return $fnum
}

#=====================================
#fuc name: getFnumsAndConfigs
#descr: 获取输入目录下的全部的configs和文件的数量,命令行里的cut 参数是15是因为日志格式的
#      标准格式是awstats-XX-XXXX-.(中间横杆分割线是为了分割，分别是常数，月份，年份，点)
#param: 输入第一个是目标目录的地址，第二是文件的后缀名，第三个是数据存储的变量名
#return: None
#=====================================
function getFnumsAndConfigs(){
	##返回的数据是两两一组的 前面是数量，后面是config
	info=($(ls $1 | cut -c 15- |sort -n |uniq -ci | sed "s/.$2//"))
	for lindex in ${!info[@]};do
		if [ $[lindex % 2] != 0 ];then
			continue
		fi
		ftempNum=${info[$lindex]}
		nextIndex=$lindex+1
		ftempConfig="${info[$nextIndex]}"
		hput $3 $ftempConfig $ftempNum
	done
}

#=====================================
#fuc name: getConfigsLogInfo
#descr: 获取输入目录下的全部的configs和其日志日期信息,cut里面的参数为8是因为awstats这个常数项
#param: 输入第一个是目标目录的地址，第二是文件的后缀名，第三个是数据存储的变量名
#return: None
#=====================================
function getConfigsLogInfo(){
	info=($(ls $1 | cut -c 8- |sort -n | sed "s/.$2//" |uniq))
	for fname in ${info[@]};do
	   logDate=${fname:0:6}
	   logConfig=${fname#*.}
	   res=`hget $3 $logConfig`
	   if [ -z "${res[@]}" ];then
		resTemp=("$logDate")
		echo "不包含$logConfig 返回空！$logDate"
	   else
		resTemp=("${res[*]}" "$logDate")
		echo "包含$logConfig,日期为：$logDate 不返回空！"${resTemp[@]}
	   fi
	   hput $3 $logConfig "${resTemp[@]}"
	   res=`hget $3 $logConfig`
	   info1=($res)
	   echo $info1
	   echo ${res[@]}
	done
}


function mergeInfo(){
	echo "merge info!"
}


function initLogConfigs(){
	echo "init log configs!"
}



########
# MAIN #
########

fileInfoArr=[]
#获取全部的文件,一定要有外面的括号
files=($(ls $DataDir))


#=====================================
#文件名格式：awstats122017.share.com.txt
#也就是awstats+月份+年份+config.txt
#其中前面的是固定的，也就是月份不足2位的由0补足，然后和最后txt中间的就是config的名称；
#====================================
for index in ${!files[@]}; do
	filename=${files[$index]}
	#转换为数组
	info=(${filename//./ })
	fileInfoArr[$index]=${info[@]}
done

echo "文件个数是："${#fileInfoArr[@]}

#获取当前日期和时间
CURRENTDATE=$(date +%Y-%m-%d)
UPDATETIME=$(date "+%Y-%m-%d %H:%M:%S")

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
#echo ${configs[@]}

for config in ${configs[@]};do
	getFlogNum $DataDir $config $logSuffix
	result=$?
	#logsNumDic[$config]=$result
done
#echo ${!logsNumDic[@]}
#echo ${logsNumDic[@]}

#获取文件config名称和文件数量
getFnumsAndConfigs $DataDir $logSuffix logsNumDic
#获取文件config名称和日志日期信息
getConfigsLogInfo  $DataDir $logSuffix logsDateDic

echo ${logsDateDic["kejsoqixiang"]}
shareLogs=(`hget logsDateDic "kejsoqixiang"`)
echo ${#shareLogs[@]}
