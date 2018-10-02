Aw2Sql 
=====================  
本项目起源：项目最初是想将awstats统计的结果（是txt文档）弄成一个api来服务，但是由于不懂的perl。
故而找了这方面的一些资料，最终找到这个项目——能把结果数据解析到mysql数据库中去。但是运行的时候出现了一些问题；
然后学习了一下perl，进行了一些初步的改动。

对于使用本项目生成多数据库的数据（每次新的config都生成新的数据库），可以结合另外一个系统[log-analytics](https://github.com/zw231212/log-analytics)
来进行数据的维护，log-analytics提供根据每个从config来作为id查询数据库的数据。

项目的最初搭建教程是参考：https://blog.csdn.net/jiedushi/article/details/6414726
如果此项目和任何LICENSE有冲突，或者原作者有意见，都可直接issue@me!

source code from :[sourceforge](http://sourceforge.net/projects/aw2sql/); [homepage](http://aw2sql.sourceforge.net/)

Aw2Sql is a Perl CLI script which analyze the results of Awstats and store them
into a MySQL database. After this you can query this results from your own site
and create a personalized design to the statistics.
The main purpose of this script is to generate personalized statistics for your
website. The default Awstats results are ugly, and difficult to integrate into an
existing website.

Aw2Sql is covered under the GNU General Public License (GPL)
copyright 2005-02-15 by Miguel Angel Liebana (th3 th1nk3r) 

Basic Usage
==================

*  Use aw2sql.pl: 

    (do the dependency、2nd and then jump to the 6th!)
    
    dependencies:
    
          (1)perl;
          (2)mysql
          (3)DBI
          (4)Data-ShowTable
          (5)DBD-mysql
          at this version,tested on: DBI-1.601.tar.gz、Data-ShowTable-3.3.tar.gz、DBD-mysql-3.0007_1.tar.gz
     
    1st: Copy aw2sql.pl script to the awstats directory （not necessary）
    
    2nd: Edit aw2sql.pl and change the values of:(changed) 
    
          $DataDir   => Directory where you store the awstats temp files
          $dbuser    => You must select a username
          $dbpass    => You must select a password
          $dbhost    => Where is MySQL server?

          Ex:
            $DataDir = '/www/awstats'
            $dbuser  = 'myuser'
            $dbpass  = 'secret'
            $dbhost  = 'localhost'

        also: you could config these param in file:conf/aw2sql.conf;
        
    3rd: # chown root:root aw2sql.pl

    4th: # chmod 711 aw2sql.pl

    5th: Create the database into MySQL.（not necessary）
    
        The default database is "mysite"_log.
        What this means? If your site is www.mysite.com, and you have an awstats'
        config file named: "awstats.mysite.conf", you will generate a temp file
        with the name: "awstats022005.mysite.txt".
        The numbers are month and year (022005 == february 2005).
        You must create this database before running the script. In this version,
        the script doesn't create the database.
        (Note: this was improved，create database is no longer needed!)
    
    6th: Run the script
    
        $ ./aw2sql.pl -config=mysite ## this would find the current(now) month and 
        current year's file!

         You can run the script and generate a specific month/year with
        $ ./aw2sql.pl -config=mysite -month=12 -year=2004

    Note: You only can use awstats temp files with text format, don't use
     the xml format!!
     
    Related Projects: [log-analytics](https://github.com/zw231212/log-analytics)
     

* Use aw2sql.sh
        
      使用脚本自动处理结果目录下的全部的解析文件，直接运行脚本文件aw2sql.sh(必须可执行)。
      
      ./aw2sql.sh
      
      最后会在conf目录下生成三个文件，分别是：
          *  logs-dates.txt ：存储全部的config和其每个config生成的日期的信息；
          *  logs-configs.txt ：存储config解析相关的一些信息
          *  logs-last-date.txt ：存储最后解析入库的日志解析结果的文件的日期
          
      每次自动运行这个文件即可对目标目录下的全部config进行执行，现在对应的执行命令那行是注释掉的
      （#result=($(./aw2sql.pl -config=$mconf -year=$year -month=$month))），最后加上定时执行任务的话
      那么就不用管日志解析结果了，只需要让别人上传日志解析结果文件到执行目录即可，如果需要查看统计信息，
      去读取conf下面的几个文件即可。
      

* Use aw2sql-1db.pl

    使用这个脚本可以使得日志解析结果都存储到一个数据库里面去，每个表里面都有config来说明这行记录属于哪个config；
    你需要到conf/aw2sql.conf里面指定数据库的名称，如果数据库不存在将会创建一个新的数据库；
    它的使用方法和aw2sql.pl是一样的，如果要aw2sql.sh 这个bash 脚本运行目标目录下的全部解析结果并且将结果全部存储到同一个数据库，
    只需要将脚本名称修改一下即可，其他的不用多变化。
     
数据表与网页上数据对照说明
------------------------
基本字段说明：
  pages ：网页数；
  hits ：文件数；
  bandwidth ：字节数；
  year_month: 年份和月份；
  config:解析结果的config；（在数据都存储到同一个数据库的时候有用！）
 
  * 摘要数据、按月历史统计数据和主机（相关的数据统计数据）对应表：general ；
  * 按日期统计数据对应表：daily
  * 按星期来统计数据对应表：
  * 每小时浏览次数：hours
  * 参观者的网域或国家：domain
  * 主机和最近参观日期、无法反解译的IP地址的数据对应表：visitors
  * 搜索引擎网站的机器人对应表：robot；
  * 每次参观所花时间：session ；
  * 文件类别：filetypes
  * url网址，也就是浏览的网页，还有入站处（entry不能为0），出站处（exit不为0）的数据对应表：pages
  * 操作系统、无法得知的操作系统数据对于表：os与unkos
  * 浏览器与无法得知的浏览器对应表数据：browser与unkbrowser
  * 链接网站的方法：origin
  * 用以搜索的短语和用以搜索的关键词：searchwords 和searchkeywords
  * HTTP错误码：errors对应总表，errors404,errors400,errors403对应各自错误的页面
  * 下载文档数据对应表：downloads；
     
Changelog
-----------
2018-10-02 zzq <191550636@qq.com>

   * 增加自动处理DataDir下全部日志解析结果的脚本文件；
   * 增加将全部数据都存储到同一个数据库的脚本文件；

2018-09-29 zzq <191550636@qq.com>

   * 修改表结构，在一些清空表格的操作上，修改为删除当前year和month相同的数据，同时对于大部分的表增加一列year_month，同时修改一些表的key；
   * 对于剩余没有添加year_month的表进行添加，并修改部分表的key以及开始清空表的操作改为删除操作；
   * 从配置文件中读取数据库配置信息；
   * 增加对pages,unkos,unkbrowser三表的部门字段长度处理，以及url和agent字段进行预编译后执行处理；
   * 增加downloads,errors403,errors400表；
   
2018-09-24 zzq <191550636@qq.com>

   * 自动创建数据库；
   * 数据库表部分字段全部加长（也许有不合适，但是为了避免异常还是加上）；

2005-02-15 th3 th1nk3r <th1nk3r@users.sourceforge.net>

   * aw2sql.pl: Release the version beta

2005-02-12 th3 th1nk3r <th1nk3r@users.sourceforge.net>

   * aw2sql.pl: Test the version alpha

2005-02-11 th3 th1nk3r <th1nk3r@users.sourceforge.net>

   * aw2sql.pl: Added options to select month and year
   * aw2sql.pl: The script now requires a special database


History
-------

In Feb of 2005, I was remaking my blog administration page, and I wasn't very
content with my statistics. I use Awstats to parse the apache logs, and link
directly to static html results (I don't like to use the CGI Awstats version, I
use Awstats with cron).

Then I decided to code a script who stores the results into a MySQL database.
This way, I can use the results in any of my websites, with my own design, and
a total integration.

After some tries, I decided to learn Perl and made my first perl script.
Well, this is my first perl script, and I think can help someone out of here.
This is the reason to free the script with GPL.


Note
----

This is a personal script, and may be isn't suitable for you. It creates many
tables (23 tables are too many), this is the main reason to use a database
for the statistics of each site.
In this version (0.1 beta) you can't decide what tables do you want to create
and how, but it's easy to change the script source.

Use the script as a guide to create your own script, not as a full program.
Perhaps in futur versions we have a config file and can configure what do you
want to output to the SQL database and how.

Thanks
-------
First, I want to thank my girlfriend, [Allyenna](http://i-dream.allyenna.net),
because her inconditional support and her encouragement in the dificult
moments :*
And of course, she is the artist who have created the website for this project ;)

修改详情
-------
在原始的项目基础上进行了如下的改动：
    
   * 自动创建数据库（config+"_log"）的形式；
   * 修改了一些数据库表字段的长度限制——原来插入的时候的一直报错；
   * 修改了一些插入的时候数据报错的地方；
   * 表结构修改：好几个表都会根据每月清空覆盖，所以需要添加year_month，然后根据以前的key来进行结合进行更新；
   
   |    表名    |       key       |      操作     |
   |:-------:|:------------- | ----------:|
   |   hours |    year_month+hour    |   更新   |
   |   domain |    year_month+code    |   更新   |
   |   session |    year_month+range   |   更新   |
   |   pages |    id   |   开始删除同year_month数据   |
   |   robot |    id   |   开始删除同year_month数据   |
   |   origin |    year_month+from   |   开始删除同year_month数据   |
   |   filetypes |    year_montj+type   |   更新   |
   |   unkos |       |      |
   |   unkbrowser |       |      |
   |   error_404 |       |      |
   |   visitors |       |      |

   上面的表就是在原来没有year_month或者day的表基础上增加year_month字段；
   * 对于剩余没有添加year_month的表进行添加，并修改部分表的key以及开始清空表的操作改为删除操作；
   * 增加从conf/aw2sql.conf来读取数据库的配置文件的操作；增加对pages，unkos，unkbrowser这三
    表中字段的处理：长度限制以及对url，agent插入的时候进行预编译后执行插入的方式；
   * 增加downloads,errors403,errors400表；
   * 增加自动处理DataDir下全部日志解析结果的脚本文件；
   * 增加将全部的数据都存储到同一个数据库的脚本文件；




