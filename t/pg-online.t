use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_PG_DSN=postgresql://localhost' unless $ENV{TEST_PG_DSN};

my $tmpdb         = DBIx::TempDB->new($ENV{TEST_PG_DSN});
my $database_name = $tmpdb->url->path->parts->[0];
my $dbh           = DBI->connect($tmpdb->dsn);

is $dbh->{pg_db}, $database_name, "pg_db $database_name";

done_testing;
