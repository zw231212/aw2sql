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

#一些参数声明
declare -A logsDateDic
declare -A logsNumDic
declare -A versionsDic
declare -A createDatesDic
declare -A parseInfo
##下面这两个貌似没怎么用到
declare -a statisticArr
declare -a datesArr
logsDateDic=()
logsNumDic=()
##文件名，分别是config相关的操作记录信息 日志的日期信息 以及最后入库的日志的结果日志日期
CONFILE="./conf/logs-configs.txt"
DATEFILE="./conf/logs-dates.txt"
LASTLOGFILE="./conf/logs-last-date.txt"

##文件描述
CONFIGFILEDESCR="# 记录信息为config createDate lastUpdateTime lastLogDate fnum version ，分别记录config名称，createDate表示创建日期，lastUpdateTime最后更新时间，lastLogTime 表示最后的日志日期 ，fnum表示文件数量，version更新的次数version"
LOGDATEDESCR="# 记录config名称和解析日志结果文件的日期XXXX-XX，日期格式是年份+月份(与在解析结果里面是XX-XXXX，为了排序方便进行了这样的转换)"
LASTLOGDESCR="# 每个config最后解析记录信息的日期，也就是上一次解析到了哪里"

CURRENTDATE=$(date +%Y-%m-%d)
UPDATETIME=$(date "+%Y-%m-%d-%H-%M-%S")


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
#param: 输入第一个是带排序的数组，第二个是排序参数，没有就顺序，有就逆序，比如-r
#return: None
#=====================================
function sortArr(){
    array=($1)
    sortedArray=($(
    for val in ${array[@]};do
	    echo "$val"
    done | sort $2
    ))
    echo "${sortedArray[*]}"
    unset array sortedArray  val
}

#=====================================
#fuc name: getFlogNum
#descr: 根据config名称来获取日志文件数量，如果一个config的配置包含在另外一个config中，那么统计的数量会有错误；
#如果在config后面再添加文件的后缀了这样就会不好不一样了?这里的结果有数量限制。结果数量大于255的话，使用另外的形式
# 获取解析结果，而不要读取result
#param: 输入第一个是目标目录的地址，第二个是config的名称 第三个是文件的后缀名
#return: 返回符合条件的日志的个数
#=====================================
function getFlogNum(){
	fnum=$(ls $1 | grep "$2.$3" | wc -l)
	echo "$fnum"
	return $fnum
}

#=====================================
#fuc name: result2Dic
#descr: 将命令行的结果解析成字典形式数据，第一列是key，第二列是value
#param: 输入第一个是命令行结果，第二个是要存储的dic的名称
#return: None
#=====================================
function result2Dic(){
    array=($1)
    for i in ${!array[@]};do
      if [ $[i % 2] == 0 ];then
        continue
      fi
      val=${array[i]}
      j=$[i-1]
      key="${array[j]}"
      hput $2 $key $val
	  done
	  unset array i j val key
}


#=====================================
#fuc name: getFnumsAndConfigs
#descr: 获取输入目录下的全部的configs和每类文件的数量,命令行里的cut 参数是15是因为日志解析结果的
#      标准格式是"awstats-XX-XXXX-." (中间横杆分割线是为了分割，分别是常数，月份，年份，点)
#param: 输入第一个是目标目录的地址，第二是文件的后缀名，第三个是数据存储的变量名
#return: None
#=====================================
function getFnumsAndConfigs(){
	##返回的数据是两两一组的 前面是数量，后面是config ,最后的awk是将两列互换
	info=($(ls $1 | cut -c 15- |sort -n |uniq -ci | sed "s/.$2//" | awk '{print $2,$1}'))
	##将结果转换为dic
	result2Dic "${info[*]}" $3
	##进行资源释放
	unset info
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
#		    echo "包含$logConfig,日期为：$logDate 不返回空！"${resTemp[@]}
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
  unset info fname logMonth logYear logDate logConfig resTemp res
  unset ckey sortedArr dateArr
}

#=====================================
#fuc name: fileStorageInfo
#descr: 将目标目录下的日志的信息存储到文件里面，日志文件
#param: None
#return: None
#=====================================
function fileStorageInfo(){
    confKeys=(${!logsNumDic[@]})
    ##获取config 与version信息
    versions=($(cat $CONFILE | grep -v '#' | awk -F ' ' '{print $1,$NF}'))
    ##组成version字典
    result2Dic "${versions[*]}" versionsDic

    ##获取config 与createDate信息
    createDates=($(cat $CONFILE | grep -v '#' | awk -F ' ' '{print $1,$2}'))
    ##组成createDates字典
    result2Dic "${createDates[*]}" createDatesDic

    ##往文件里输入描述
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
       ##
       ## 记录信息为config createDate lastUpdateTime lastLogDate fnum version
       sinfo=$ckey" "$ccdate" "$UPDATETIME" "${logsDates[0]}" "${logsNumDic[$ckey]}" "$rversion
       ## 记录的信息为config:[dates](后面表示的是日志的解析结果时间)
       linfo=$ckey":""${logsDates[@]}"
       echo "$sinfo" >> $CONFILE
       echo "$linfo" >> $DATEFILE
       statisticArr[$cindex]=$sinfo
       datesArr[$cindex]=$linfo
    done
    unset confKeys versions createDates cindex ckey logDates ccdate rversion ccdate  sinfo linfo
}

function mergeInfo(){
	echo "merge info!"
}


function initLogConfigs(){
	echo "init log configs!"
}


#=====================================
#fuc name: handleLastDatelog
#descr: 将最后处理的config的日期记录数据读出来写入dic
#param: None
#return: None
#=====================================
function handleLastDatelog(){
	##读取最后日志解析的时间
	pinfo=($(cat $1 | grep -v '#' | awk -F ' ' '{print $1,$2}'))
	#不存在，也就是初始化的时候,从最后一个日志生成
	if [ -z "${pinfo[*]}" ];then
		echo "不存在最后日期配置文件"
		confs=${!logsNumDic[@]}
		for conf in ${confs[@]};do
		    logDateArr=(${logsDateDic[$conf]})
		    len=${#logDateArr[@]}
		    parseInfo[$conf]=${logDateArr[$[len-1]]}
		done
	else
		echo "存在配置文件！"
		result2Dic "${pinfo[*]}" parseInfo
	fi
	unset pinfo confs conf len logDateArr
}



########
# MAIN #
########

#获取文件config名称和文件数量
getFnumsAndConfigs $DataDir $logSuffix logsNumDic
#获取文件config名称和日志日期信息
getConfigsLogInfo  $DataDir $logSuffix logsDateDic

# 配置文件信息生成
fileStorageInfo


#获取config最后解析入库的日志时间
handleLastDatelog $LASTLOGFILE

echo $LASTLOGDESCR > $LASTLOGFILE

confs=(${!logsDateDic[@]})
for mconf in ${confs[@]};do
	logDates=(${logsDateDic[$mconf]})
	LogLENTH=${#logDates[@]}
	lastDate=${parseInfo[$mconf]}
	##检查是否为空
	if [ -z "$lastDate" ];then
		lastDate=0
	fi
	for logDate in ${logDates[@]};do
		echo $logDate":"$lastDate
		if [ $logDate -lt $lastDate ];then
			echo "小于最小日期，不执行！"
			continue
		fi
		year=${logDate:0:4}
		month=${logDate:4:2}
		echo $mconf">>"$month">>"$year
		##正式执行结果入库程序
		#result=($(./aw2sql.pl -config=$mconf -year=$year -month=$month))
		#echo $result
		#if [  "$result" = "0" ];then
			#echo "发生异常，$result"
			#break;
		#fi;
	done
	parseInfo[$mconf]=${logDates[0]}
	echo $mconf" "${parseInfo[$mconf]} >> $LASTLOGFILE
done

