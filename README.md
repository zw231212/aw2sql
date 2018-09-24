======
Aw2Sql
======
```
项目起源：项目最初是想将awstats统计的结果（是txt文档）弄成一个api来服务，但是由于不懂的perl。
故而找了这方面的一些资料，最终找到这个项目。然后学习了一下perl，进行了一些初步的改动。
改动：
（1）自动创建数据库（config+"_log"）的形式；
（2）修改了一些数据库表字段的长度限制，原来插入的时候的一直报错；
（3）修改了一些插入的时候数据报错的地方；

项目的最初搭建教程是参考：https://blog.csdn.net/jiedushi/article/details/6414726
如果此项目和任何LICENSE有冲突，或者原作者有意见，都可直接issue@me!

```

http://sourceforge.net/projects/aw2sql/
http://aw2sql.sourceforge.net/

Aw2Sql is a Perl CLI script which analyze the results of Awstats and store them
into a MySQL database. After this you can query this results from your own site
and create a personalized design to the statistics.
The main purpose of this script is to generate personalized statistics for your
website. The default Awstats results are ugly, and difficult to integrate into an
existing website.

Aw2Sql is covered under the GNU General Public License (GPL)
copyright 2005-02-15 by Miguel Angel Liebana (th3 th1nk3r) <th1nk3r@users.sourceforge.net>


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

