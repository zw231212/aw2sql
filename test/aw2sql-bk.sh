#!/bin/bash
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
#  > Author: zhangzhiquan
#  > Mail  : zhangzq_job@163.com 191550636@qq.com
#  > Gmail : zw231212@gmail.com
#  > Web   : https://github.com/zw231212/aw2sql
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

echo "#######################################"
echo "# aw2sql.sh基本输出:"

#读取配置文件信息
while read line;do
  eval "$line"
done < "conf/aw2sql.conf"

#打印配置文件的信息
echo "# awstats results data dir: $DataDir"
echo "# db infomation: "
echo "# host: $dbhost"
echo "# port: $dbport"
echo "# user: $dbuser"
echo "# pass: $dbpass"
echo "# logSuffix: $logSuffix"
echo "######################################"
#查看awstats结果文件目录是否存在,以及检查是否存在文件
fileNums=$(ls $DataDir | wc -l)
if [ ! -d $DataDir -o $fileNums -le 0 ];then
	echo "$DataDir is not existed!"
	exit 0
fi

declare -A logsDateDic
declare -A logsNumDic
declare -A versionsDic
declare -A createDatesDic
declare -a statisticArr
declare -a datesArr
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
    eval "$1"["$2"]='$3'
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

#====================================
#fuc name: sortArr
#descr: 对数组进行排序
#param: 输入第一个是数组，第二个是排序参数
#return: None
#=====================================
function sortArr(){
    ARRAY=($1)
    SortedArray=($(
    for val in ${ARRAY[@]};do
	echo "$val"
    done | sort $2
    ))
    echo "${SortedArray[*]}"
    unset ARRAY SortedArray
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
		nextIndex=$[lindex+1]
		ftempConfig="${info[$nextIndex]}"
		hput $3 $ftempConfig $ftempNum
	done
	#进行资源释放
	unset info lindex ftempNum nextIndex ftempCinfig
}

#=====================================
#fuc name: getConfigsLogInfo
#descr: 获取输入目录下的全部的configs和其日志日期信息,cut里面的参数为8是因为awstats这个常数项
#param: 输入第一个是目标目录的地址，第二是文件的后缀名，第三个是数据存储的变量名
#return: None
#=====================================
function getConfigsLogInfo(){
    ##结果是逆序的，靠参数sort -rn来实现
	info=($(ls $1 | cut -c 8- | sed "s/.$2/ /" |sort -rn | uniq))
	for fname in ${info[@]};do
	   logMonth=${fname:0:2}
	   logYear=${fname:2:4}
	   logDate=$logYear$logMonth
	   logConfig=${fname#*.}
	   res=`hget logsDateDic "$logConfig"`
	   if [ -z "${res[*]}" ];then
		resTemp=("$logDate")
		echo "不包含key：$logConfig 返回空，初始时间是：$logDate"
	   else
		resTemp=("${res[@]}" "$logDate")
#		echo "包含$logConfig,日期为：$logDate 不返回空！"${resTemp[@]}
	   fi
	   logsDateDic[$logConfig]="${resTemp[*]}"
    done
    ##对结果数组进行排序
    for ckey in ${!logsDateDic[@]};do
        dateArr=(${logsDateDic[$ckey]})
        sortedArr=`sortArr "${dateArr[*]}" -r`
        logsDateDic[$ckey]="${sortedArr[*]}"
    done
    #进行资源释放
    unset ckey sortedArr
    unset info fname logMonth logYear logDate logConfig resTemp res
}

#=====================================
#fuc name: fileStorageInfo
#descr: 将目标目录下的日志的信息存储到文件里面，日志文件
#param: None
#return: None
#=====================================
function fileStorageInfo(){
    confKeys=(${!logsNumDic[@]})
    CURRENTDATE=$(date +%Y-%m-%d)
    UPDATETIME=$(date "+%Y-%m-%d-%H-%M-%S")
    ##文件名
    CONFILE="./conf/logs-configs.txt"
    DATEFILE="./conf/logs-dates.txt"

    ##文件描述
    CONFIGFILEDESCR="# 分别记录config名称，createDate表示创建日期，lastUpdateTime最后更新时间，lastLogTime 表示最后的日志日期 ，fnum表示文件数量，version更新的次数version"
    LOGDATEDESCR="# 记录config名称和日志的日期XXXX-XX，年份+月份"

    ##获取config 与version信息
    versions=($(cat ./conf/logs-configs.txt| grep -v '#' | awk -F ' ' '{print $1,$NF}'))
    #组成version字典

    for vindex in ${!versions[@]};do
		if [ $[vindex % 2] == 0 ];then
			continue
		fi
		vsion=${versions[$vindex]}
		formerIndex=$[vindex-1]
		vconfig="${versions[formerIndex]}"
		hput versionsDic $vconfig $vsion
    done

    ##获取config 与createDate信息
    createDates=($(cat ./conf/logs-configs.txt| grep -v '#' | awk -F ' ' '{print $1,$2}'))
    #组成createDates字典

    for cindex in ${!createDates[@]};do
		if [ $[cindex % 2] == 0 ];then
			continue
		fi
		cdate=${createDates[$cindex]}
		if [ -z "$cdate" ];then
		   cdate=$CURRENTDATE
		fi
		cformerIndex=$[cindex-1]
		cconfig="${createDates[cformerIndex]}"
		hput createDatesDic $cconfig $cdate
    done

    ##输入描述
    echo $CONFIGFILEDESCR >  $CONFILE
    echo $LOGDATEDESCR >  $DATEFILE

    ##遍历将一些统计和日志的信息写入文件里面
    for cindex in ${!confKeys[@]};do
       ckey=${confKeys[$cindex]}
       rversion=$[${versionsDic[$ckey]}+1]
       logsDates=(${logsDateDic[$ckey]})
       ccdate=${createDatesDic[$ckey]}
       if [ -z "$ccdate" ];then
		ccdate=$CURRENTDATE
       fi
       sinfo=$ckey" "$ccdate" "$UPDATETIME" "${logsDates[0]}" "${logsNumDic[$ckey]}" "$rversion
       linfo=$ckey":""${logsDates[@]}"
       echo "$sinfo" >> $CONFILE
       echo "$linfo" >> $DATEFILE
       statisticArr[$cindex]=$sinfo
       datesArr[$cindex]=$linfo
    done
    unset confKeys CURRENTDATE UPDATETIME CONFILE DATEFILE ckey logDates
    unset sinfo linfo vindex versions vsion formerIndex vconfig
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

# 配置文件信息
fileStorageInfo
