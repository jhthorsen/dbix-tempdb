use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_PG_DSN=postgresql://localhost' unless $ENV{TEST_PG_DSN};

my $tmpdb = DBIx::TempDB->new($ENV{TEST_PG_DSN});

done_testing;
