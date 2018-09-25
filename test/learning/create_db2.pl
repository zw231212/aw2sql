#!/usr/bin/env perl
use DBI;
use strict;

my $db_host = "10.2.16.3";
my $db_username = "root";
my $db_pass = "Tiger!2018";
my $db_name = "test12";

my $dbh = DBI->connect("DBI:mysql:host=$db_host",$db_username,$db_pass,{'RaiseError'=>1});

my $rdbname=$db_name."_log";

$dbh->do("CREATE DATABASE IF NOT EXISTS $rdbname;");
$dbh->disconnect();
