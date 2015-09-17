use Test::More;
use DBIx::TempDB;

plan skip_all => 'TEST_MYSQL_DSN=mysql://localhost' unless $ENV{TEST_MYSQL_DSN};

my $tmpdb = DBIx::TempDB->new($ENV{TEST_MYSQL_DSN});

done_testing;
