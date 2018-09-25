#!/usr/bin/env perl

use DBI;
my $db_name = "test12";
my $db_host = "XXXXXXX";
my $db_port = '3306';
my $username = "root";
my $pass = "XXXX";

my $dsn = "dbi:mysql:database=${db_name};hostname=${db_host};port=${db_port}";

print $dsn;
print("\n");
#获取驱动程序对象句柄
my $drh = DBI->install_driver("mysql");

#if($rc=$drh->func('dropdb', $db_name, $db_host, $username, $pass, 'admin')) {
#	print("drop db `",$db_namem,"` succssfully!\n");
#}

#创建数据库$db_name
$rc=$drh->func("createdb",$db_name ,$db_host,$username,$pass,"admin")or
    die "failed to create database ",$db_name,"!\n";
print("create database `",$db_name,"` successfully!\n");


