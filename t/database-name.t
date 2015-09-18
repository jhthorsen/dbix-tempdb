use strict;
use Test::More;
use DBIx::TempDB;

my $tmpdb    = DBIx::TempDB->new('postgresql://example.com', auto_create => 0);
my $exe      = File::Basename::basename($0);
my $hostname = Sys::Hostname::hostname();
my $uid      = $<;

$exe =~ s!\W!_!g;
$hostname =~ s!\W!_!g;

my $name = $tmpdb->_generate_database_name(0);
like $name, qr/^[\w-]+$/, 'alpanum plus dash';
like $name, qr/^tmp_${uid}_database_name_t_\w+$/, 'tmp + uid + script + host';

$name = $tmpdb->_generate_database_name(1);
like $name, qr/^tmp_${uid}_database_name_t_\w+_1$/, 'tmp + uid + script + host + 1';

$tmpdb->{template} = 'bar%i_%H_%P_%T_%U_%X_foo';
$name = $tmpdb->_generate_database_name(0);
is $name, join('_', 'bar', $hostname, $$, $^T, $<, $exe, 'foo'), $name;

$name = $tmpdb->_generate_database_name(3);
is $name, join('_', 'bar', 3, $hostname, $$, $^T, $<, $exe, 'foo'), $name;

done_testing;
