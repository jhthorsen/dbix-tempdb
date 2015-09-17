use Test::More;
use DBIx::TempDB;

my $tmpdb = DBIx::TempDB->new('postgresql://example.com', auto_create => 0);
my $uid = $<;

my $name = $tmpdb->_generate_database_name(0);
diag $name;
like $name, qr/^[\w-]+$/, 'alpanum plus dash';
like $name, qr/^\w+_${uid}_database_name_t$/, 'ends with test script name';

$name = $tmpdb->_generate_database_name(1);
like $name, qr/^\w+_${uid}_database_name_t_1$/, 'ends with test script name_1';

done_testing;
