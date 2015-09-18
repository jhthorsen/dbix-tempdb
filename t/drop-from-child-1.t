use strict;
use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_PG_DSN=postgresql://localhost' unless $ENV{TEST_PG_DSN};

my $database_name;

{
  my $tmpdb = DBIx::TempDB->new($ENV{TEST_PG_DSN}, drop_from_child => 1);
  my $dbh = DBI->connect($tmpdb->dsn);
  $database_name = $tmpdb->url->path->parts->[0];
  is $dbh->{pg_db}, $database_name, "pg_db $database_name";
}

wait;    # drop database process

{
  my $tmpdb = DBIx::TempDB->new($ENV{TEST_PG_DSN}, drop_from_child => 1);
  my $dbh = DBI->connect($tmpdb->dsn);
  is $dbh->{pg_db}, $database_name, "pg_db $database_name";
}

done_testing;
