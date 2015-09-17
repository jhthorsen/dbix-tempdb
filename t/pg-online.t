use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_PG_DSN=postgresql://localhost' unless $ENV{TEST_PG_DSN};

my $tmpdb = DBIx::TempDB->new($ENV{TEST_PG_DSN}, auto_create => 0);
is $ENV{DBIX_TEMP_DB_URL}, undef, 'DBIX_TEMP_DB_URL is not set';

$tmpdb->create_database;
my $database_name = $tmpdb->url->path->parts->[0];
is $ENV{DBIX_TEMP_DB_URL}, "$ENV{TEST_PG_DSN}/$database_name", 'DBIX_TEMP_DB_URL is set';

my $dbh = DBI->connect($tmpdb->dsn);
is $dbh->{pg_db}, $database_name, "pg_db $database_name";

done_testing;
