use Test::More;
use DBIx::TempDB;

my $tmpdb = DBIx::TempDB->new('mysql://example.com', auto_create => 0, database_name => 'foo');

is $tmpdb->url, 'mysql://example.com', 'url';

is_deeply(
  [$tmpdb->dsn],
  [
    'dbi:mysql:dbname=foo;host=example.com',
    undef, undef, {AutoCommit => 1, AutoInactiveDestroy => 1, PrintError => 0, RaiseError => 1, mysql_enable_utf8 => 1}
  ],
  'dsn for foo'
);

$tmpdb = DBIx::TempDB->new('mysql://u:p@127.0.0.1:1234?AutoCommit=0', auto_create => 0, database_name => 'yikes');
is_deeply(
  [$tmpdb->dsn],
  [
    'dbi:mysql:dbname=yikes;host=127.0.0.1;port=1234',
    'u', 'p', {AutoCommit => 0, AutoInactiveDestroy => 1, PrintError => 0, RaiseError => 1, mysql_enable_utf8 => 1}
  ],
  'dsn for tikes'
);

is_deeply(
  [DBIx::TempDB->dsn('mysql://x:y@example.com:2345/aiaiai')],
  [
    'dbi:mysql:dbname=aiaiai;host=example.com;port=2345',
    'x', 'y', {AutoCommit => 1, AutoInactiveDestroy => 1, PrintError => 0, RaiseError => 1, mysql_enable_utf8 => 1}
  ],
  'dsn for class'
);

done_testing;
