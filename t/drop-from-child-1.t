use strict;
use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_PG_DSN=postgresql://localhost' unless $ENV{TEST_PG_DSN};

my @dsn;

{
  my $tmpdb         = DBIx::TempDB->new($ENV{TEST_PG_DSN}, drop_from_child => 1);
  my @dsn           = $tmpdb->dsn;
  my $dbh           = DBI->connect(@dsn);
  my $database_name = $tmpdb->url->dbname;
  is $dbh->{pg_db}, $database_name, "pg_db $database_name";
}

wait;    # drop database process
ok !eval { DBI->connect(@dsn); 1 }, 'database cleaned up';

done_testing;
