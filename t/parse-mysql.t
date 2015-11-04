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

  drop table if exists y;
--
-- Table: y
--
create table y (
  foo varchar(255)
);

--    some
-- comment
delimiter //
create table if not exists y (bar varchar(255))//
set foreign_key_checks=1//
HERE
  [
    "SET foreign_key_checks=0",
    "drop table if exists y",
    "--\n-- Table: y\n--\ncreate table y (\n  foo varchar(255)\n)",
    "--    some\n-- comment\n",
    "create table if not exists y (bar varchar(255))",
    "set foreign_key_checks=1",
  ],
  'multiple statements'
);

done_testing;
