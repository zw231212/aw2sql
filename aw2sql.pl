#!/usr/bin/perl

# ----- aw2sql 0.1 beta (c) 2005 Miguel Angel Liebana -----
# Aw2sql comes with ABSOLUTELY NO WARRANTY. It's a free software distributed
# with a GNU General Public License (See LICENSE file for details).


# Important:
# You must configure some basic info to start using this script:
#
#   $DataDir = '/www/awstats' => Where do you store the awstat temp files
#   $dbuser = 'user'          => User name for mysql
#   $dbpass = 'secret'        => Password to access mysql
#   $host = 'localhost'       => Where is the mysql server
#
# This script creates a database for each domain you want to control.
# This database must be named like your "config file"_log. Example:
#  If you name your config file:
#         /etc/awstats/awstats.myserver.conf
#  And awstats creates temp files with the name:
#         awstats022005.myserver.txt
#  Then your database must be named "myserver_log". Easy, don't you think?
#

require 5.005;
# use warnings;
# use warnings FATAL => 'all';
use DBI;
use Getopt::Long;
use Time::Local;
use strict;no strict "refs";

use vars qw/
$VERSION $DIR $PROG $Extension $SiteConfig $DataDir $MonthConfig $YearConfig $help
$nowsec $nowmin $nowhour $nowday $nowmonth $nowyear $nowwday $nowyday
@data @dataname @datanumelem
$dsn $dbuser $dbpass $dbhost $dbh $sth $rows $sql @ary @tables
%general %daily %hours %session %domain %os %unkos %browser %unkbrowser %ft
%screen %misc %worms %robot %errors %e404 %visit %pages %origin
%searchref %pageref %searchwords %searchkeywords $year_month
/;

$DataDir='/opt/awstats/results/'; # <=== Directory where you store the awstats temp files
$dbuser='root';           # <=== You must select a username
$dbpass='Tiger!2018';         # <=== You must select a password
$dbhost='10.2.16.3';      # <=== Where is the database?
my $dbport='3306';

$VERSION="0.1"; # Version of this script
$DIR=''; # Path of this script
$PROG=''; # Name of this script without the extension (aw2db)
$Extension=''; # Extension of this script (pl)
$SiteConfig=''; # What site do you want to add to the database? Database name = $Site_Config + "_log"
$MonthConfig=''; # If you want to save the info of a month
$YearConfig=''; # If you want to save the info of a year

#############
# Functions #
#############

#------------------------------------------------------------------------------
# Function:   Shows an error message and exits
# Parameters: Message with the error details
# Input:    None
# Output:   None
# Return:   None
#------------------------------------------------------------------------------
sub error
{
  print "Error: $_[0]\n";
    exit 1;
}

#------------------------------------------------------------------------------
# Function:   Shows a warning
# Parameters: Message with the warning details
# Input:    None
# Output:   None
# Return:   None
#------------------------------------------------------------------------------
sub warning
{
  print "Warning: $_[0]\n";
}

#------------------------------------------------------------------------------
# Function:   Calc the number of days in a specific month
# Parameters: Month and year
# Input:    None
# Output:   None
# Return:   None
#------------------------------------------------------------------------------
sub NumberDays
{
  my $mo = $_[0];
  my $ye = $_[1] - 1900;
  my $nextmonth;
  # how many days have this month.. first minute of the next month, minus an hour (jeje)
  if($mo eq 12){ $nextmonth=timelocal(0,0,0,1,0,$ye+1); }
  else { $nextmonth=timelocal(0,0,0,1,$mo,$ye); }
  $nextmonth = $nextmonth - 3600;
  my @m = localtime($nextmonth); # translate this time into sec, min, hours, ...
  return $m[3]; # We only need the number of day
}

#------------------------------------------------------------------------------
# Function:   Reads the data of the temp awstats file and stores this info into
#             an array.
# Parameters: None
# Input:    $DataDir $SiteConfig $MonthConfig $YearConfig
# Output:   @data @dataname @datanumelem
# Return:   None
#------------------------------------------------------------------------------
sub Read_Data
{
  my $filename="awstats".$MonthConfig.$YearConfig.".".$SiteConfig.".txt";
  if (!(-s "$DataDir$filename") || !(-r "$DataDir$filename") || !(open(DATA, "$DataDir$filename")))
  { error("Can't find the data file:\n\t$DataDir$filename"); }

  my $seccion;
  my $num;
  my $begin=0;  # Indicates if we are into a section
  my @temp;     #

  while(defined(my $line=<DATA>))
  {
    chomp $line; s/\r//;

    if ($line =~ /^\s*#/) { next; } # Ignore the comments
    $line =~ s/\s#.*$//;

    if($line =~ /^BEGIN_([^&]+)/i) # We save the name and number of elements of the section
    {
      ($seccion,$num)=split(/ /, $1);
      push(@dataname,$seccion); # The name of the section
      push(@datanumelem,$num);  # The number of elements of this section (same array index)
      $begin=1;
      next;
    }
    elsif(($begin == 1) && ($line=~ /^END_$seccion/))
    {
      $begin=0;
      push(@data, [@temp]); # Multiarray
      $#temp = -1; # Empty the temp array
      next;
    }
    elsif($begin == 1)
    {
      push(@temp, $line);
      next;
    }
  }
  close(DATA);
}

#------------------------------------------------------------------------------
# Function:   Returns if a table exists into the database
# Parameters: The name of the table you want to search
# Input:    @tables
# Output:   None
# Return:   1 if the table exists
#------------------------------------------------------------------------------
sub Search_Table
{
  my $is;
  $is=0;
  if($#tables == 0) { $is=0; }
  else
  {
    $is=0;
    foreach my $table (@tables)
    {
      if ($table eq $_[0]) { $is=1; }
    }
  }
  return $is;
}

#------------------------------------------------------------------------------
# Function:   This function creates a table into the database
# Parameters: Name of the table you want to create
# Input:    $dbh
# Output:   None
# Return:   None
#------------------------------------------------------------------------------
sub Create_Table
{
  my $s;
  if($_[0] eq "general")
  {
    $s = "CREATE TABLE `general` ( ".
           "`year_month` VARCHAR( 16 ) NOT NULL , ".
           "`visits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`visits_unique` MEDIUMINT UNSIGNED NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`pages_nv` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits_nv` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth_nv` BIGINT UNSIGNED NOT NULL , ".
           "`hosts_known` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hosts_unknown` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `year_month` ) );";
  }
  elsif($_[0] eq "daily")
  {
    $s = "CREATE TABLE `daily` ( ".
           "`day` VARCHAR( 64 ) NOT NULL , ".
           "`visits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `day` ) );";
  }
  elsif($_[0] eq "hours")
  {
    $s = "CREATE TABLE `hours` ( ".
           "`year_month` VARCHAR( 16 ) NOT NULL , ".
           "`hour` TINYINT UNSIGNED NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `year_month`, `hour` ) );";
  }
  elsif($_[0] eq "session")
  {
    $s = "CREATE TABLE `session` ( ".
           "`range` VARCHAR(64) NOT NULL , ".
           "`visits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `range` ) );";
  }
  elsif($_[0] eq "domain")
  {
    $s = "CREATE TABLE `domain` ( ".
           "`code` VARCHAR(16) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `code` ) );";
  }
  elsif($_[0] eq "os")
  {
    $s = "CREATE TABLE `os` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`name` VARCHAR(64) NOT NULL , ".
           "`year_month` VARCHAR( 16 ) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) , INDEX (`name`) );";
  }
  elsif($_[0] eq "unkos")
  {
    $s = "CREATE TABLE `unkos` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`agent` VARCHAR(255) NOT NULL , ".
           "`lastvisit` VARCHAR(64) NOT NULL , ".
           "PRIMARY KEY ( `id` ) , INDEX (`agent`) );";
  }
  elsif($_[0] eq "browser")
  {
    $s = "CREATE TABLE `browser` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`name` VARCHAR(64) NOT NULL , ".
           "`year_month` VARCHAR( 16 ) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) , INDEX (`name`) );";
  }
  elsif($_[0] eq "unkbrowser")
  {
    $s = "CREATE TABLE `unkbrowser` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`agent` VARCHAR(255) NOT NULL , ".
           "`lastvisit` VARCHAR(64) NOT NULL , ".
           "PRIMARY KEY ( `id` ) , INDEX (`agent`) );";
  }
  elsif($_[0] eq "filetypes")
  {
    $s = "CREATE TABLE `filetypes` ( ".
           "`type` VARCHAR(16) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`bwwithoutcompress` BIGINT UNSIGNED NOT NULL , ".
           "`bwaftercompress` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `type` ) );";
  }
  elsif($_[0] eq "screen")
  {
    $s = "CREATE TABLE `screen` ( ".
           "`size` VARCHAR(32) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `size` ) );";
  }
  elsif($_[0] eq "misc")
  {
    $s = "CREATE TABLE `misc` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`text` VARCHAR(128) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "worms")
  {
    $s = "CREATE TABLE `worms` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`text` VARCHAR(128) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`lastvisit` VARCHAR(64) NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "robot")
  {
    $s = "CREATE TABLE `robot` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`name` VARCHAR(128) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`lastvisit` VARCHAR(64) NOT NULL , ".
           "`hitsrobots` MEDIUMINT UNSIGNED NOT NULL, ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "errors")
  {
    $s = "CREATE TABLE `errors` ( ".
           "`code` VARCHAR(16) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `code` ) );";
  }
  elsif($_[0] eq "errors404")
  {
    $s = "CREATE TABLE `errors404` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`url` VARCHAR(256) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`referer` VARCHAR(256) NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "visitors")
  {
    $s = "CREATE TABLE `visitors` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`host` VARCHAR(255) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL, ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`lastvisit` VARCHAR(64) NOT NULL , ".
           "`startlastvisit` VARCHAR(64) , ".
           "`lastpage` VARCHAR(255) , ".
           "PRIMARY KEY ( `id` ) , INDEX (`lastvisit`) );";
  }
  elsif($_[0] eq "pages")
  {
    $s = "CREATE TABLE `pages` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`url` VARCHAR(255) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL, ".
           "`bandwidth` BIGINT UNSIGNED NOT NULL , ".
           "`entry` MEDIUMINT UNSIGNED NOT NULL , ".
           "`exit` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "origin")
  {
    $s = "CREATE TABLE `origin` ( ".
           "`from` VARCHAR(64) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL, ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `from` ) );";
  }
  elsif($_[0] eq "searchref")
  {
    $s = "CREATE TABLE `searchref` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`engine` VARCHAR(128) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL, ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "pageref")
  {
    $s = "CREATE TABLE `pageref` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`url` VARCHAR(255) NOT NULL , ".
           "`pages` MEDIUMINT UNSIGNED NOT NULL, ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "searchwords")
  {
    $s = "CREATE TABLE `searchwords` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`words` VARCHAR(255) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }
  elsif($_[0] eq "searchkeywords")
  {
    $s = "CREATE TABLE `searchkeywords` ( ".
           "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT , ".
           "`words` VARCHAR(255ll) NOT NULL , ".
           "`hits` MEDIUMINT UNSIGNED NOT NULL , ".
           "PRIMARY KEY ( `id` ) );";
  }

  $dbh->do($s);
}

#------------------------------------------------------------------------------
# Function:   Search a section and returns its index for @data
# Parameters: The name of the section you want to search
# Input:    @dataname
# Output:   None
# Return:   Index of -1 if can't be found
#------------------------------------------------------------------------------
sub Search_Sec
{
  if($#dataname == 0) { error("Empty databame array"); }
  else
  {
    for ( my $x=0;$x<=$#dataname;$x++)
    {
      if ($dataname[$x] eq $_[0]) { return $x; }
    }
  }
  warning("The section ".$_[0]." can't be found");
  return -1;
}

#------------------------------------------------------------------------------
# Function:   Search the index of an element into a section of the data array
# Parameters: Name of the section and the element
# Input:    @data @datanumelem
# Output:   None
# Return:   Index of the element, or -1 if can't be found
#------------------------------------------------------------------------------
sub Search_Elem
{
  my $sec = Search_Sec($_[0]);
  my $elem = $_[1];
  my $num= $datanumelem[$sec];
  if($#data == 0) { error("Empty data array"); }
  else
  {
    for ( my $z=0;$z<$num;$z++)
    {
        if ($data[$sec][$z] =~ /^$elem([^&]+)/i) { return $z; }
    }
  }
  #warning("The element ".$elem." of section ".$_[0]." doesn't exists.");
  return -1;
}

#------------------------------------------------------------------------------
# Function:   Returns the info of a data index
# Parameters: Name of the section and element you want to read
# Input:    @data
# Output:   None
# Return:   The content of a data element or a "0 0 0 0 0 0 ..." string
#------------------------------------------------------------------------------
sub Read_Elem
{
  my $sec = Search_Sec($_[0]);
  my $elem = Search_Elem($_[0],$_[1]);

  if($sec==-1 || $elem==-1)
  { return "0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"; }
  else
  { return $data[$sec][$elem]; }
}

#------------------------------------------------------------------------------
# Function:   Adds al the values of the column and returns the result
# Parameters: Name of the section and the column you want to calculate
# Input:    @data @datanumelem
# Output:   None
# Return:   Add result
#------------------------------------------------------------------------------
sub Suma_Colum
{
  my $sec = Search_Sec($_[0]); # seccion a mirar
  my $colum = $_[1] -1;        # columna a sumar
  my $num= $datanumelem[$sec]; # numero de elementos de la seccion
  my $suma=0;
  my @value;

  if($#data == 0) { error("Vector de datos vacio"); }
  else
  {
    for ( my $z=0;$z<$num;$z++)
    {
      @value = split(/ /, $data[$sec][$z]);
      $suma=$suma + $value[$colum];
      $#value = -1;
    }
  }
  return $suma;
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the general table
# Parameters: None
# Input:    $YearConfig $MonthConfig
# Output:   %general
# Return:   None
#------------------------------------------------------------------------------
sub Read_General
{
  my $t; # valor dummy $YearConfig
  $general {'year_month'} = $YearConfig.$MonthConfig;
  ($t,$general{'visits'}) = split(/ /, Read_Elem("GENERAL","TotalVisits"));
  ($t,$general{'visits_unique'}) = split(/ /, Read_Elem("GENERAL","TotalUnique"));
  $general{'pages'} = Suma_Colum("DAY",2); # sumar la segunda columna
  $general{'hits'} = Suma_Colum("DAY",3);
  $general{'bandwidth'} = Suma_Colum("DAY",4);
  $general{'pages_nv'} = Suma_Colum("TIME",5);
  $general{'hits_nv'} = Suma_Colum("TIME",6);
  $general{'bandwidth_nv'} = Suma_Colum("TIME",7);
  ($t,$general{'hosts_known'}) = split(/ /, Read_Elem("GENERAL","MonthHostsKnown"));
  ($t,$general{'hosts_unknown'}) = split(/ /, Read_Elem("GENERAL","MonthHostsUnKnown"));
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the daily table
# Parameters: $tempdate => what day you want to read stats?
# Input:    $YearConfig $MonthConfig
# Output:   %daily
# Return:   None
#------------------------------------------------------------------------------
sub Read_Daily
{
  my $t; # valor dummy
  my $day = $_[0];

  $daily {'day'} = $YearConfig.$MonthConfig.$day;
  ($t, $daily{'pages'}, $daily{'hits'}, $daily{'bandwidth'}, $daily{'visits'}) = split(/ /, Read_Elem("DAY",$daily{'day'}));
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the hours table
# Parameters: Of what hour we want the stats
# Input:    None
# Output:   %hours
# Return:   None
#------------------------------------------------------------------------------
sub Read_Hours
{
  my $readhour = $_[0];
  ($hours{'hour'}, $hours{'pages'}, $hours{'hits'}, $hours{'bandwidth'}) = split(/ /, Read_Elem("TIME",$readhour));
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the Session table
# Parameters: The session element we want to read stats
# Input:    @data
# Output:   %session
# Return:   None
#------------------------------------------------------------------------------
sub Read_Session
{
  my $sec = Search_Sec("SESSION");
  my $id = $_[0];
  ($session{'range'}, $session{'visits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the domain table
# Parameters: The domain/countrie we want to read stats
# Input:    @data
# Output:   %domain
# Return:   None
#------------------------------------------------------------------------------
sub Read_Domain
{
  my $sec = Search_Sec("DOMAIN");
  my $id = $_[0];
  ($domain{'code'}, $domain{'pages'}, $domain{'hits'}, $domain{'bandwidth'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the OS table
# Parameters: The os we want to read stats
# Input:    @data $YearConfig $MonthConfig
# Output:   %os
# Return:   None
#------------------------------------------------------------------------------
sub Read_OS
{
  my $sec = Search_Sec("OS");
  my $id = $_[0];
  ($os{'name'}, $os{'hits'}) = split(/ /, $data[$sec][$id]);
  $os{'year_month'} = $YearConfig.$MonthConfig;
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the unkos table
# Parameters: The unknown OS we want to read stats
# Input:    @data
# Output:   %unkos
# Return:   None
#------------------------------------------------------------------------------
sub Read_unkos
{
  my $sec = Search_Sec("UNKNOWNREFERER");
  my $id = $_[0];
  ($unkos{'agent'}, $unkos{'lastvisit'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the browser table
# Parameters: The browser we want to read stats
# Input:    @data $YearConfig $MonthConfig
# Output:   %browser
# Return:   None
#------------------------------------------------------------------------------
sub Read_Browser
{
  my $sec = Search_Sec("BROWSER");
  my $id = $_[0];
  ($browser{'name'}, $browser{'hits'}) = split(/ /, $data[$sec][$id]);
  $browser{'year_month'} = $YearConfig.$MonthConfig;
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the unkbrowser table
# Parameters: The unknown browser we want to read stats
# Input:    @data
# Output:   %unkbrowser
# Return:   None
#------------------------------------------------------------------------------
sub Read_unkbrowser
{
  my $sec = Search_Sec("UNKNOWNREFERERBROWSER");
  my $id = $_[0];
  ($unkbrowser{'agent'}, $unkbrowser{'lastvisit'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the filetypes table
# Parameters: The file type we want to read stats
# Input:    @data
# Output:   %ft
# Return:   None
#------------------------------------------------------------------------------
sub Read_FileTypes
{
  my $sec = Search_Sec("FILETYPES");
  my $id = $_[0];
  ($ft{'type'}, $ft{'hits'}, $ft{'bandwidth'}, $ft{'bwwithoutcompress'}, $ft{'bwaftercompress'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the screen table
# Parameters: The screen resolution we want to read stats
# Input:    @data
# Output:   %screen
# Return:   None
#------------------------------------------------------------------------------
sub Read_Screen
{
  my $sec = Search_Sec("SCREENSIZE");
  my $id = $_[0];
  ($screen{'size'}, $screen{'hits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the misc table
# Parameters: The misc element we want to read stats
# Input:    @data
# Output:   %misc
# Return:   None
#------------------------------------------------------------------------------
sub Read_Misc
{
  my $sec = Search_Sec("MISC");
  my $id = $_[0];
  ($misc{'text'}, $misc{'pages'}, $misc{'hits'}, $misc{'bandwidth'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the worms table
# Parameters: The worms we want to read stats
# Input:    @data
# Output:   %worms
# Return:   None
#------------------------------------------------------------------------------
sub Read_Worms
{
  my $sec = Search_Sec("WORMS");
  my $id = $_[0];
  ($worms{'text'}, $worms{'hits'}, $worms{'bandwidth'}, $worms{'lastvisit'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the robots table
# Parameters: The robots we want to read stats
# Input:    @data
# Output:   %robots
# Return:   None
#------------------------------------------------------------------------------
sub Read_Robot
{
  my $sec = Search_Sec("ROBOT");
  my $id = $_[0];
  ($robot{'name'}, $robot{'hits'}, $robot{'bandwidth'}, $robot{'lastvisit'}, $robot{'hitsrobots'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the errors table
# Parameters: The error id we want to read stats
# Input:    @data
# Output:   %errors
# Return:   None
#------------------------------------------------------------------------------
sub Read_Errors
{
  my $sec = Search_Sec("ERRORS");
  my $id = $_[0];
  ($errors{'code'}, $errors{'hits'}, $errors{'bandwidth'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the errors404 table
# Parameters: The error id we want to read stats
# Input:    @data
# Output:   %e404
# Return:   None
#------------------------------------------------------------------------------
sub Read_Errors404
{
  my $sec = Search_Sec("SIDER_404");
  my $id = $_[0];
  ($e404{'url'}, $e404{'hits'}, $e404{'referer'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the visitors table
# Parameters: The visitor index we want to read stats
# Input:    @data
# Output:   %visit
# Return:   None
#------------------------------------------------------------------------------
sub Read_Visitors
{
  my $sec = Search_Sec("VISITOR");
  my $id = $_[0];
  ($visit{'host'}, $visit{'pages'}, $visit{'hits'}, $visit{'bandwidth'}, $visit{'lastvisit'}, $visit{'startlastvisit'}, $visit{'lastpage'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the pages more visited table
# Parameters: The page index we want to read stats
# Input:    @data
# Output:   %pages
# Return:   None
#------------------------------------------------------------------------------
sub Read_Pages
{
  my $sec = Search_Sec("SIDER");
  my $id = $_[0];
  ($pages{'url'}, $pages{'pages'}, $pages{'bandwidth'}, $pages{'entry'}, $pages{'exit'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data of the origin of the visits
# Parameters: The row we want to read
# Input:    @data
# Output:   %origin
# Return:   None
#------------------------------------------------------------------------------
sub Read_Origin
{
  my $sec = Search_Sec("ORIGIN");
  my $id = $_[0];
  ($origin{'from'}, $origin{'pages'}, $origin{'hits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data with the search referrers
# Parameters: The engine we want to read
# Input:    @data
# Output:   %searchref
# Return:   None
#------------------------------------------------------------------------------
sub Read_Searchref
{
  my $sec = Search_Sec("SEREFERRALS");
  my $id = $_[0];
  ($searchref{'engine'}, $searchref{'pages'}, $searchref{'hits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data with referrers from other pages
# Parameters: The referrer we want to read
# Input:    @data
# Output:   %pageref
# Return:   None
#------------------------------------------------------------------------------
sub Read_Pageref
{
  my $sec = Search_Sec("PAGEREFS");
  my $id = $_[0];
  ($pageref{'url'}, $pageref{'pages'}, $pageref{'hits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data with the search words
# Parameters: The word
# Input:    @data
# Output:   %searchwords
# Return:   None
#------------------------------------------------------------------------------
sub Read_Searchwords
{
  my $sec = Search_Sec("SEARCHWORDS");
  my $id = $_[0];
  ($searchwords{'words'}, $searchwords{'hits'}) = split(/ /, $data[$sec][$id]);
}

#------------------------------------------------------------------------------
# Function:   Creates the data with the search words
# Parameters: The word
# Input:    @data
# Output:   %searchkeywords
# Return:   None
#------------------------------------------------------------------------------
sub Read_Searchkeywords
{
  my $sec = Search_Sec("KEYWORDS");
  my $id = $_[0];
  ($searchkeywords{'words'}, $searchkeywords{'hits'}) = split(/ /, $data[$sec][$id]);
}

########
# Main #
########

# We save the path of the scritp and its name
($DIR=$0) =~ s/([^\/\\]+)$//; ($PROG=$1) =~ s/\.([^\.]*)$//; $Extension=$1;
$DIR||='.'; $DIR =~ s/([^\/\\])[\\\/]+$/$1/;

my $starttime=time();
($nowsec,$nowmin,$nowhour,$nowday,$nowmonth,$nowyear,$nowwday,$nowyday) = localtime($starttime);

if ($nowyear < 100) { $nowyear+=2000; } else { $nowyear+=1900; }
if (++$nowmonth < 10) { $nowmonth = "0$nowmonth"; }
if ($nowday < 10) { $nowday = "0$nowday"; }
if ($nowhour < 10) { $nowhour = "0$nowhour"; }
if ($nowmin < 10) { $nowmin = "0$nowmin"; }
if ($nowsec < 10) { $nowsec = "0$nowsec"; }

GetOptions("config=s"=>\$SiteConfig,
           "month=i"=>\$MonthConfig,
           "year=i"=>\$YearConfig);

if (! $SiteConfig){
  print "\n";
  print "----- $PROG $VERSION (c) 2005 Miguel Angel Liebana -----\n";
  print "Aw2sql is a free analyzer that parses the AWStats (copyright of Laurent\n";
  print "Destailleur) and saves its results into a MySQL database.\n";
  print "After this is done,you can show this results from PHP, perl, ASP or other\n";
  print "languages, with your own website design.\n";
  print "Aw2sql comes with ABSOLUTELY NO WARRANTY. It's a free software distributed\n";
  print "with a GNU General Public License (See LICENSE file for details).\n";
  print "\n";
  print "Syntax: $PROG.$Extension -config=virtualhostname [options]\n";
  print "\n";
  print "Options:\n";
  print "  -config        the site you want to analyze (not optional)\n";
  print "  -month=MM      to output a report for an old month MM\n";
  print "  -year=YYYY     to output a report for an old year YYYY\n";
  print "\n";
  print "Example:\n";
  print "  $ ./".$PROG.$Extension." -config=mysite\n";
  print "\n";
  print "Important:\n";
  print "  In the example, the database 'mysite_log' must exists in mysql\n";
  print "  and you must modify the values of this script variables, with\n";
  print "  the proper user and pass to access the database\n";
  print "\n";
  exit 2;
}

if (! $MonthConfig) { $MonthConfig = "$nowmonth"; }
elsif (($MonthConfig <= 0) || ($MonthConfig > 12)) { error("Wrong Month"); }
elsif ($MonthConfig < 10) { $MonthConfig = "0$MonthConfig"; }
if (! $YearConfig) { $YearConfig = "$nowyear"; }
elsif (($YearConfig < 1900) || ($YearConfig > 2100)) { error("Wrong Year"); }
# Well, I don't think this script lives until the year 2100
# but who knows? xD ... I don't want a Year 2KC effect xDDD

## ����ȫ�ֱ���year_month
$year_month = $YearConfig.$MonthConfig;

#create the database if the db is not exists
$dbh = DBI->connect("DBI:mysql:host=$dbhost",$dbuser,$dbpass,{'RaiseError'=>1});
my $rdb_name = "`".$SiteConfig."_log`";
$dbh->do("CREATE DATABASE IF NOT EXISTS $rdb_name;");


Read_Data();  # Reads the temp data file of awstats


# Access the database. The database must exists.
$dsn = "DBI:mysql:database=".$SiteConfig."_log;host=".$dbhost;
# Connect to the database
$dbh = DBI->connect($dsn,$dbuser,$dbpass, {RaiseError => 0, PrintError => 0})
  or error("Imposible conectar con el servidor: $DBI::err ($DBI::errstr)\n");

# We ask for the existing tables and save them into the tables array
$sth = $dbh->prepare("show tables");
$sth->execute();
while (@ary = $sth->fetchrow_array()) { push(@tables,$ary[0]); }
$sth->finish();

#################
# GENERAL TABLE #
#################

if(! Search_Table("general")) { Create_Table("general"); }
Read_General();
$sth = $dbh->prepare("SELECT COUNT(*) FROM general WHERE `year_month`='".$general {'year_month'}."'");
$sth->execute();
my $count = $sth->fetchrow_array();
$sth->finish();

$sql = " `general` SET `year_month`='".$general{'year_month'}."', ".
       " `visits`='".$general{'visits'}."', `visits_unique`='".$general{'visits_unique'}."', ".
       " `pages`='".$general{'pages'}."', `hits`='".$general{'hits'}."', ".
       " `bandwidth`='".$general{'bandwidth'}."', `pages_nv`='".$general{'pages_nv'}."', ".
       " `hits_nv`='".$general{'hits_nv'}."', `bandwidth_nv`='".$general{'bandwidth_nv'}."', ".
       " `hosts_known`='".$general{'hosts_known'}."', `hosts_unknown`='".$general{'hosts_unknown'}."'";
if($count==0) {  $sql = "INSERT INTO".$sql.";"; }
elsif($count==1) { $sql = "UPDATE".$sql." WHERE `year_month`='".$general{'year_month'}."' LIMIT 1;"; }
else { error("There are repeated rows for the date ".$general{'year_month'}." into the 'general' table of ".$SiteConfig."\n"); }
$rows = $dbh->do($sql);
if(!$rows) { error("We can't add a new rows to the 'general' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }

###############
# DAILY TABLE #
###############

if(! Search_Table("daily")) { Create_Table("daily"); }
my $tempdate;
my $maxday;
if($nowmonth == $MonthConfig) {$maxday = $nowday;}
else {$maxday = NumberDays($MonthConfig, $YearConfig);}
for (my $i=1; $i<=$maxday; $i++)
{
  if ($i < 10) { $tempdate = "0$i"; }
  else { $tempdate = $i; }
  Read_Daily($tempdate);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM daily WHERE `day`='".$daily{'day'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `daily` SET `day`='".$daily{'day'}."', `visits`='".$daily{'visits'}."', ".
         " `pages`='".$daily{'pages'}."', `hits`='".$daily{'hits'}."', ".
         " `bandwidth`='".$daily{'bandwidth'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `day`='".$daily{'day'}."' LIMIT 1;"; }
  else { error("There are repeated rows for the date ".$daily{'day'}." into the 'daily' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new rows to the 'daily' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###############
# HOURS TABLE #
###############

# We keep only one hour history table
if(! Search_Table("hours")) { Create_Table("hours"); }
for (my $i=0; $i<=23; $i++)
{
  Read_Hours($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM hours WHERE `year_month`='".$year_month."' AND `hour` = '".$i."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();
  $sql = " `hours` SET `hour`='".$hours{'hour'}."', `pages`='".$hours{'pages'}."', ".
         " `hits`='".$hours{'hits'}."', `bandwidth`='".$hours{'bandwidth'}."', `year_month` = '".$year_month."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `year_month`='".$year_month."' AND `hour` = '".$i."'LIMIT 1;"; }
  else { error("There are repeated hours into the 'hours' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new rows to the 'hours' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

#################
# SESSION TABLE #
#################

# We keep only one hours history table
if(! Search_Table("session")) { Create_Table("session"); }
my $max = $datanumelem[Search_Sec("SESSION")];
for (my $i=0; $i<$max; $i++)
{
  Read_Session($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM session WHERE `range`='".$session{'range'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `session` SET `range`='".$session{'range'}."', `visits`='".$session{'visits'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `range`='".$session{'range'}."' LIMIT 1;"; }
  else { error("There are repeated times into the 'session' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'session' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

################
# DOMAIN TABLE #
################

if(! Search_Table("domain")) { Create_Table("domain"); }
my $max = $datanumelem[Search_Sec("DOMAIN")];
for (my $i=0; $i<$max; $i++)
{
  Read_Domain($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM domain WHERE `code`='".$domain{'code'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `domain` SET `code`='".$domain{'code'}."', `pages`='".$domain{'pages'}."', ".
         "`hits`='".$domain{'hits'}."', `bandwidth`='".$domain{'bandwidth'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `code`='".$domain{'code'}."' LIMIT 1;"; }
  else { error("There are repeated regional codes into the 'domain' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'domain' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

############
# OS TABLE #
############

if(! Search_Table("os")) { Create_Table("os"); }
my $max = $datanumelem[Search_Sec("OS")];
for (my $i=0; $i<$max; $i++)
{
  Read_OS($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM os WHERE `name`='".$os{'name'}."' AND `year_month`='".$os{'year_month'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `os` SET `name`='".$os{'name'}."', `year_month`='".$os{'year_month'}."', `hits`='".$os{'hits'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `name`='".$os{'name'}."' AND `year_month`='".$os{'year_month'}."' LIMIT 1;"; }
  else { error("There are repeated OS codes into the 'os' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'os' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###############
# unkOS TABLE #
###############

if(! Search_Table("unkos")) { Create_Table("unkos"); }
my $max = $datanumelem[Search_Sec("UNKNOWNREFERER")];

$rows = $dbh->do("TRUNCATE TABLE `unkos`"); # Vaciamos la tabla
for (my $i=0; $i<$max; $i++)
{
  Read_unkos($i);

  $sql = "INSERT INTO `unkos` SET `agent`='".$unkos{'agent'}."', `lastvisit`='".$unkos{'lastvisit'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'unkos' table in the".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

#################
# Browser TABLE #
#################

if(! Search_Table("browser")) { Create_Table("browser"); }
my $max = $datanumelem[Search_Sec("BROWSER")];
for (my $i=0; $i<$max; $i++)
{
  Read_Browser($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM browser WHERE `name`='".$browser{'name'}."' AND `year_month`='".$browser{'year_month'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `browser` SET `name`='".$browser{'name'}."', `year_month`='".$browser{'year_month'}."', `hits`='".$browser{'hits'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `name`='".$browser{'name'}."' AND `year_month`='".$browser{'year_month'}."' LIMIT 1;"; }
  else { error("There are repeated browsers' codes into the 'browser' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'browser' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

####################
# unkbrowser TABLE #
####################

if(! Search_Table("unkbrowser")) { Create_Table("unkbrowser"); }
my $max = $datanumelem[Search_Sec("UNKNOWNREFERERBROWSER")];

$rows = $dbh->do("TRUNCATE TABLE `unkbrowser`"); # Vaciamos la tabla
for (my $i=0; $i<$max; $i++)
{
  Read_unkbrowser($i);

  $sql = "INSERT INTO `unkbrowser` SET `agent`='".$unkbrowser{'agent'}."', `lastvisit`='".$unkbrowser{'lastvisit'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'unkbrowser' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###################
# filetypes TABLE #
###################

if(! Search_Table("filetypes")) { Create_Table("filetypes"); }
my $max = $datanumelem[Search_Sec("FILETYPES")];
for (my $i=0; $i<$max; $i++)
{
  Read_FileTypes($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM filetypes WHERE `type`='".$ft{'type'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `filetypes` SET `type`='".$ft{'type'}."', `hits`='".$ft{'hits'}."', ".
         "`bandwidth`='".$ft{'bandwidth'}."', `bwwithoutcompress`='".$ft{'bwwithoutcompress'}."', ".
         "`bwaftercompress`='".$ft{'bwaftercompress'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `type`='".$ft{'type'}."' LIMIT 1;"; }
  else { error("There are repeated file types into the 'filetypes' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'filetypes' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

################
# screen TABLE #
################

if(! Search_Table("screen")) { Create_Table("screen"); }
my $max = $datanumelem[Search_Sec("SCREENSIZE")];
for (my $i=0; $i<$max; $i++)
{
  Read_Screen($i);
  $sth = $dbh->prepare("SELECT COUNT(*) FROM screen WHERE `size`='".$screen{'size'}."'");
  $sth->execute();
  my $count = $sth->fetchrow_array();
  $sth->finish();

  $sql = " `screen` SET `size`='".$screen{'size'}."', `hits`='".$screen{'hits'}."'";
  if($count==0) { $sql = "INSERT INTO".$sql.";"; }
  elsif($count==1) { $sql = "UPDATE".$sql." WHERE `size`='".$screen{'size'}."' LIMIT 1;"; }
  else { error("There are repeated screen resolutions into the 'screen' table of ".$SiteConfig."\n"); }
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'screen' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

##############
# Misc TABLE #
##############

if(! Search_Table("misc")) { Create_Table("misc"); }
my $max = $datanumelem[Search_Sec("MISC")];

$rows = $dbh->do("TRUNCATE TABLE `misc`"); # Empty the table
for (my $i=0; $i<$max; $i++)
{
  Read_Misc($i);
  $sql = "INSERT INTO `misc` SET `text`='".$misc{'text'}."', `pages`='".$misc{'pages'}."', ".
         " `hits`='".$misc{'hits'}."', `bandwidth`='".$misc{'bandwidth'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'misc' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###############
# Worms TABLE #
###############

if(! Search_Table("worms")) { Create_Table("worms"); }
my $max = $datanumelem[Search_Sec("WORMS")];
$rows = $dbh->do("TRUNCATE TABLE `worms`"); # Empty the table
for (my $i=0; $i<$max; $i++)
{
  Read_Misc($i);
  $sql = "INSERT INTO `worms` SET `text`='".$worms{'text'}."', `hits`='".$worms{'hits'}."', ".
         "`bandwidth`='".$worms{'bandwidth'}."', `lastvisit`='".$worms{'lastvisit'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'worms' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###############
# Robot TABLE #
###############

if(! Search_Table("robot")) { Create_Table("robot"); }
my $max = $datanumelem[Search_Sec("ROBOT")];
$rows = $dbh->do("TRUNCATE TABLE `robot`"); # Empty the table
for (my $i=0; $i<$max; $i++)
{
  Read_Robot($i);
  $sql = "INSERT INTO `robot` SET `name`='".$robot{'name'}."', `hits`='".$robot{'hits'}."', ".
         "`bandwidth`='".$robot{'bandwidth'}."', `lastvisit`='".$robot{'lastvisit'}."', ".
         "`hitsrobots`='".$robot{'hitsrobots'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'robot' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

################
# Errors TABLE #
################

if(! Search_Table("errors")) { Create_Table("errors"); }
my $max = $datanumelem[Search_Sec("ERRORS")];
$rows = $dbh->do("TRUNCATE TABLE `errors`"); # Empty the table
for (my $i=0; $i<$max; $i++)
{
  Read_Errors($i);
  $sql = "INSERT INTO `errors` SET `code`='".$errors{'code'}."', `hits`='".$errors{'hits'}."', ".
         "`bandwidth`='".$errors{'bandwidth'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'errors' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###################
# Errors404 TABLE #
###################

# I don't think it's a good idea to include this table in the BD
# Some of the errors can risk the security of the DB
if(! Search_Table("errors404")) { Create_Table("errors404"); }
my $max = $datanumelem[Search_Sec("SIDER_404")];
$rows = $dbh->do("TRUNCATE TABLE `errors404`"); # Empty the table
for (my $i=0; $i<$max; $i++)
{
  Read_Errors404($i);
  $e404{'url'} =~ tr/'/&#039;/; # we subs the incorrect character ' with its html code
  $sql = "INSERT INTO `errors404` SET `url`='".$e404{'url'}."', `hits`='".$e404{'hits'}."', ".
         "`referer`='".$e404{'referer'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new row to the 'errors404' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

##################
# Visitors TABLE #
##################

# Visitors of the month (as in awstats)
if(! Search_Table("visitors")) { Create_Table("visitors"); }
my $max = $datanumelem[Search_Sec("VISITOR")];
$rows = $dbh->do("TRUNCATE TABLE `visitors`");
for (my $i=0; $i<$max; $i++)
{
  Read_Visitors($i);
  $sql = "INSERT INTO `visitors` SET `host`='".$visit{'host'}."', `pages`='".$visit{'pages'}."', ".
         "`hits`='".$visit{'hits'}."', `bandwidth`='".$visit{'bandwidth'}."', ".
         "`lastvisit`='".$visit{'lastvisit'}."'";
  if(!($visit{'startlastvisit'} eq '')) { $sql = $sql . ", `startlastvisit`='".$visit{'startlastvisit'}."'"; }
  if(!($visit{'lastpage'} eq '')) { $sql = $sql . ", `lastpage`='".$visit{'lastpage'}."'";}
  $sql = $sql .";";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new visitor to the 'visitors' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###############
# Pages TABLE #
###############

# Pages readed this month
if(! Search_Table("pages")) { Create_Table("pages"); }
my $max = $datanumelem[Search_Sec("SIDER")];
$rows = $dbh->do("TRUNCATE TABLE `pages`");
for (my $i=0; $i<$max; $i++)
{
  Read_Pages($i);
  my $urlInfo = $pages{'url'};
  if(!$urlInfo){
	next;
  }
  my $pagesNum = $pages{'pages'};
  $pagesNum = $pagesNum?$pagesNum:0;

  my $bandWidthNum = $pages{'bandwidth'};
  $bandWidthNum = $bandWidthNum?$bandWidthNum:0;

  my $entryNum = $pages{'entry'};
  $entryNum = $entryNum?$entryNum:0;

  my $exitNum = $pages{'exit'};
  $exitNum = $exitNum?$exitNum:0;

  $sql = "INSERT INTO `pages` SET `url`='".$pages{'url'}."', `pages`='$pagesNum', ".
         "`bandwidth`='$bandWidthNum', `entry`='$entryNum', ".
         "`exit`='$exitNum';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'pages' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

################
# Origin TABLE #
################

# From where comes our visits.
# From0 => Direct address / Bookmarks
# From1 => Unknown Origin
# From2 => Links from an Internet Search Engine (google, yahoo, etc..)
# From3 => Links from an external page (other web sites except search engines)
# From4 => Links from an internal page (other page on same site)
# From5 => Links from a NewsGroup

if(! Search_Table("origin")) { Create_Table("origin"); }
my $max = $datanumelem[Search_Sec("ORIGIN")];
$rows = $dbh->do("TRUNCATE TABLE `origin`");
for (my $i=0; $i<$max; $i++)
{
  Read_Origin($i);
  $sql = "INSERT INTO `origin` SET `from`='".$origin{'from'}."', `pages`='".$origin{'pages'}."', ".
         "`hits`='".$origin{'hits'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'origin' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

###################
# searchref TABLE #
###################

if(! Search_Table("searchref")) { Create_Table("searchref"); }
my $max = $datanumelem[Search_Sec("SEREFERRALS")];
$rows = $dbh->do("TRUNCATE TABLE `searchref`");
for (my $i=0; $i<$max; $i++)
{
  Read_Searchref($i);
  $sql = "INSERT INTO `searchref` SET `engine`='".$searchref{'engine'}."', `pages`='".$searchref{'pages'}."', ".
         "`hits`='".$searchref{'hits'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'searchref' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

#################
# pageref TABLE #
#################

if(! Search_Table("pageref")) { Create_Table("pageref"); }
my $max = $datanumelem[Search_Sec("PAGEREFS")];
$rows = $dbh->do("TRUNCATE TABLE `pageref`");
for (my $i=0; $i<$max; $i++)
{
  Read_Pageref($i);
  $sql = "INSERT INTO `pageref` SET `url`='".$pageref{'url'}."', `pages`='".$pageref{'pages'}."', ".
         "`hits`='".$pageref{'hits'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'pageref' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

#####################
# searchwords TABLE #
#####################

if(! Search_Table("searchwords")) { Create_Table("searchwords"); }
my $max = $datanumelem[Search_Sec("SEARCHWORDS")];
$rows = $dbh->do("TRUNCATE TABLE `searchwords`");
for (my $i=0; $i<$max; $i++)
{
  Read_Searchwords($i);
  $sql = "INSERT INTO `searchwords` SET `words`='".$searchwords{'words'}."', `hits`='".$searchwords{'hits'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'searchwords' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}

########################
# searchkeywords TABLE #
########################

if(! Search_Table("searchkeywords")) { Create_Table("searchkeywords"); }
my $max = $datanumelem[Search_Sec("KEYWORDS")];
$rows = $dbh->do("TRUNCATE TABLE `searchkeywords`");
for (my $i=0; $i<$max; $i++)
{
  Read_Searchkeywords($i);
  $sql = "INSERT INTO `searchkeywords` SET `words`='".$searchkeywords{'words'}."', `hits`='".$searchkeywords{'hits'}."';";
  $rows = $dbh->do($sql);
  if(!$rows) { error("We can't add a new entry to the 'searchkeywords' table in the ".$SiteConfig."_log database.\n $DBI::err ($DBI::errstr)"); }
}


#$sth->finish();
$dbh->disconnect();

