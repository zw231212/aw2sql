====== <br/>
Aw2Sql  <br/>
======  <br/>

项目起源：项目最初是想将awstats统计的结果（是txt文档）弄成一个api来服务，但是由于不懂的perl。
故而找了这方面的一些资料，最终找到这个项目——能把结果数据解析到mysql数据库中去。但是运行的时候出现了一些问题；
然后学习了一下perl，进行了一些初步的改动，后期抽空再改动改动！改动如下：

（1）自动创建数据库（config+"_log"）的形式；

（2）修改了一些数据库表字段的长度限制，原来插入的时候的一直报错；

（3）修改了一些插入的时候数据报错的地方；

（4）hours表每次每月都会覆盖，修改为：根据年月+hour来作为id生成,表增加新列year_month；

（5）domain表每次每月都会覆盖，修改为：根据年月+code来作为id生成,表增加新列year_month；
session表是根据year_month+range来作为key；pages和robot只是增加一列year_month，
而且修改初始的清空表的操作，只是删除当前year_month相同的数据列;origin表增加year_month,
year_month+from来作为key，同时修改一开始清空表格为删除数据的操作；
filetypes是根据year_montj+type来作为key；
unkos和unkbrowser增加一列，同时修改清空表格的操作为删除当前year_month的信息；
修改errors表，增加year_month+type为key，增加year_month列到error_404表；
增加visitors表上的year_month列，修改一开始的清空表格为删除；

（6）对于没有添加year_month的表进行添加，并修改部分表的key以及开始清空表的操作改为删除操作；


项目的最初搭建教程是参考：https://blog.csdn.net/jiedushi/article/details/6414726
如果此项目和任何LICENSE有冲突，或者原作者有意见，都可直接issue@me!


source code from :[sourceforge](http://sourceforge.net/projects/aw2sql/) ;[homepage](http://aw2sql.sourceforge.net/)

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
    dependencies:
      (1)perl;
      (2)mysql
      (3)DBI
      (4)Data-ShowTable
      (5)DBD-mysql
      at this version,tested on :DBI-1.601.tar.gz、Data-ShowTable-3.3.tar.gz、DBD-mysql-3.0007_1.tar.gz
     
     
    1st: Copy aw2sql.pl script to the awstats directory （not necessary）

    2nd: Edit aw2sql.pl and change the values of:
          $DataDir   => Directory where you store the awstats temp files
          $dbuser    => You must select a username
          $dbpass    => You must select a password
          $dbhost    => Where is MySQL server?

          Ex:
            $DataDir = '/www/awstats'
            $dbuser  = 'myuser'
            $dbpass  = 'secret'
            $dbhost  = 'localhost'

    3rd: # chown root:root aw2sql.pl

    4th: # chmod 711 aw2sql.pl

    5th: Create the database into MySQL. The default database is "mysite"_log.
      What this means? If your site is www.mysite.com, and you have an awstats'
      config file named: "awstats.mysite.conf", you will generate a temp file
      with the name: "awstats022005.mysite.txt".
      The numbers are month and year (022005 == february 2005).
      You must create this database before running the script. In this version,
      the script doesn't create the database.
      (Note: improved，create database is no longer needed!)
    6th: Run the script
        $ ./aw2sql.pl -config=mysite ## this would find the current(now) month and 
        current year's file!

         You can run the script and generate a specific month/year with
        $ ./aw2sql.pl -config=mysite -month=12 -year=2004

    Note: You only can use awstats temp files with text format, don't use
     the xml format!!
     
数据表与网页对照说明
------------------------
```
基本字段说明：
  pages ：网页数；
  hits ：文件数；
  bandwidth ：字节数；
（1）摘要数据、按月历史统计数据和主机（相关的数据统计数据）对应表：general ；
（2）按日期统计数据对应表：daily
（3）按星期来统计数据对应表：
（4）每小时浏览次数：hours
（5）参观者的网域或国家：domain
（6）主机和最近参观日期、无法反解译的IP地址的数据对应表：visitors
（7）搜索引擎网站的机器人对应表：robot；
（8）每次参观所花时间：session ；
（9）文件类别：filetypes
（10）下载：download，暂缺
（11）url网址，也就是浏览的网页，还有入站处（entry不能为0），出站处（exit不为0）的数据对应表：pages
（12）操作系统、无法得知的操作系统数据对于表：os与unkos
（13）浏览器与无法得知的浏览器对应表数据：browser与unkbrowser
（14）链接网站的方法：origin
（15）用以搜索的短语和用以搜索的关键词：searchwords 和searchkeywords
（16）HTTP错误码：errors对应总表，error404对应各自错误的页面

```

     
Changelog
-----------
2018-09-28 zzq <191550636@qq.com>

        * 修改表结构，在一些清空表格的操作上，修改为删除当前year和month相同的数据，同时对于大部分的表增加一列year_month，同时修改一些表的key；
        * 对于没有添加year_month的表进行添加，并修改部分表的key以及开始清空表的操作改为删除操作；
        
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
