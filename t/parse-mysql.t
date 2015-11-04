use strict;
use Test::More;
use DBIx::TempDB;

is_deeply(
  [DBIx::TempDB->_parse_mysql('SET foreign_key_checks=0')],
  ['SET foreign_key_checks=0'],
  'SET foreign_key_checks=0'
);

is_deeply(
  [DBIx::TempDB->_parse_mysql(<<'HERE')],

SET foreign_key_checks=0;

create table if not exists migration_test_one (
  foo varchar(255)
);

  drop table if exists migration_test_one;
--    some
-- comment
delimiter //
create table if not exists migration_test_two (bar varchar(255))//
set foreign_key_checks=1//
HERE
  [
    "SET foreign_key_checks=0",
    "create table if not exists migration_test_one (\n  foo varchar(255)\n)",
    "drop table if exists migration_test_one",
    "--    some\n-- comment\n",
    "create table if not exists migration_test_two (bar varchar(255))",
    "set foreign_key_checks=1",
  ],
  'multiple statements'
);

done_testing;
