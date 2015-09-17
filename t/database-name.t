use Test::More;
use DBIx::TempDB;

my $tmpdb = DBIx::TempDB->new('postgresql://example.com', auto_create => 0);
my $uid = $<;

my $name = $tmpdb->_generate_database_name(0);
like $name, qr/^[\w-]+$/, 'alpanum plus dash';
like $name, qr/^tmp_${uid}_database_name_t_\w+$/, 'tmp + uid + script + host';

$name = $tmpdb->_generate_database_name(1);
like $name, qr/^tmp_${uid}_database_name_t_\w+_1$/, 'tmp + uid + script + host + 1';

done_testing;
