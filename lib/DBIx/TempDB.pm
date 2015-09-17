package DBIx::TempDB;

=head1 NAME

DBIx::TempDB - Create a temporary database

=head1 VERSION

0.01

=head1 DESCRIPTION

L<DBIx::TempDB> is a module which allow you to create a temporary database,
which only lives as long as your process is alive. This can be very
convenient when you want to run unit tests in parallel, without messing
up the state.

=head1 SYNOPSIS

  use Test::More;
  use DBIx::TempDB;
  use DBI;

  # create a temp database
  my $tmpdb = DBIx::TempDB->new("postgresql://postgres@localhost");

  # print complete url to db server with database name
  diag $tmpdb->url;

  # run sql commands in the test database
  $tmpdb->execute("CREATE ...");
  $tmpdb->execute_file("path/relative/to/test.script");

  # connect to the temp database
  my $db = DBI->connect($tmpdb->dsn);

  # run tests...

  done_testing;
  # database is cleaned up when test exit

=cut

use strict;
use warnings;
use DBI;

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head2 replace_me

=cut

has replace_me => sub {};

=head1 METHODS

=head2 replace_me

=cut

sub replace_me {
  my $self = shift;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
