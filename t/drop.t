use strict;
use Test::More;
use DBIx::TempDB;

my %test = (mysql => $ENV{TEST_MYSQL_DSN}, pg => $ENV{TEST_PG_DSN}, sqlite => eval 'require DBD::SQLite;"sqlite:"');
delete $test{$_} for grep { !$test{$_} } keys %test;

plan skip_all => 'No live testing is set up' unless %test;

my @tables;
for my $test_case (sort keys %test) {
  subtest $test_case => sub {
    my $tmpdb1 = DBIx::TempDB->new($test{$test_case});
    ok tables($tmpdb1), 'tempdb1' or diag "tables=@tables, err=$@";

    my $tmpdb2 = DBIx::TempDB->new($test{$test_case});
    $tmpdb2->drop_databases;
    ok !tables($tmpdb1), 'tmpdb1 dropped' or diag "tables=@tables, err=$@";
    ok tables($tmpdb2),  'tmpdb2'         or diag "tables=@tables, err=$@";

    $tmpdb2->drop_databases({self => 'include'});
    $tmpdb2->drop_databases;    # should never fail
    ok !tables($tmpdb2), 'drop self' or diag "tables=@tables, err=$@";

    eval { $tmpdb2->drop_databases({self => 'only'}) };
    ok $@, 'self is already dropped';
  };
}

done_testing;

sub create_table {
  shift->dbh->do('create table users (name text)');
}

sub tables {
  my $tmpdb = shift;
  @tables = ();
  return eval { @tables = $tmpdb->dbh->tables(undef, undef, undef, undef); 1 } ? 1 : 0;
}
