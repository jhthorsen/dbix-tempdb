package DBIx::TempDB;

=head1 NAME

DBIx::TempDB - Create a temporary database

=head1 VERSION

0.01

=head1 DESCRIPTION

L<DBIx::TempDB> is a module which allow you to create a temporary database,
which only lives as long as your process is alive. This can be very
convenient when you want to run tests in parallel, without messing up the
state between tests.

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
use Carp 'confess';
use DBI;
use File::Basename ();
use Mojo::URL;
use Sys::Hostname ();

use constant MAX_NUMBER_OF_TRIES => $ENV{TEMP_DB_MAX_NUMBER_OF_TRIES} || 20;

our $VERSION = '0.01';

=head1 METHODS

=head2 create_database

  $self = $self->create_database;

This method will create a temp database for the current process. Calling this
method multiple times will simply do nothing.

=cut

sub create_database {
  my $self = shift;
  my ($dbi, $guard, $name);

  return $self if $self->{database_name};

  {
    local $self->{database_name} = $self->_schema_database;
    $dbi = DBI->connect($self->dsn);
  }

  local $@;
  while (++$guard < MAX_NUMBER_OF_TRIES) {
    $name = $self->_generate_database_name($guard);
    eval {1} or next;
    $self->{database_name} = $name;
    $self->{url}->path($name);
    return $self;
  }

  confess "Could not create unique database: '$name'. $@";
}

=head2 dsn

  ($dsn, $user, $pass, $attrs) = $self->dsn;

Will parse L</url> and return a list of arguments suitable for L<DBI/connect>.

Note that this method cannot be called before L</create_database> is called.

=cut

sub dsn {
  my $self = shift;
  confess 'Cannot return dsn before create_database() is called.' unless $self->{database_name};
  $self->can(sprintf '_dsn_for_%s', $self->url->scheme)->($self);
}

=head2 new

  $self = DBIx::TempDB->new($url, %args);

Creates a new object after checking the C<$url> is valid. C<%args> can be:

=over 4

=item * auto_create

L</create_database> will be called automatically, unless C<auto_create> is
set to a false value.

=back

=cut

sub new {
  my $class   = shift;
  my $url     = Mojo::URL->new(shift || '');
  my $self    = bless {@_, url => $url}, $class;
  my $dsn_for = sprintf '_dsn_for_%s', $url->scheme || '';

  unless ($self->can($dsn_for)) {
    confess "Cannot generate temp database for '@{[$url->scheme]}'. $class\::$dsn_for() is missing";
  }

  $self->{url} = $url;
  $self->{pid} = ($self->{fork_watch} // 1) ? $$ : undef;
  return $self->create_database if $self->{auto_create} // 1;
  return $self;
}

=head2 url

  $url = $self->url;

Returns the input URL as L<URL> object, with L<path|URL/path> set to the temp
database name.

Note that this method cannot be called before L</create_database> is called.

=cut

sub url { shift->{url} }

sub _dsn_for_postgresql {
  my $self = shift;
  my $url  = $self->url;
  my %opt  = %{$url->query->to_hash};
  my $dsn  = "dbi:Pg:dbname=$self->{database_name}";
  my @userinfo;

  if (my $host = $url->host) { $dsn .= ";host=$host" }
  if (my $port = $url->port) { $dsn .= ";port=$port" }
  if (($url->userinfo // '') =~ /^([^:]+)(?::([^:]+))?$/) { @userinfo = ($1, $2) }
  if (my $service = delete $opt{service}) { $dsn .= "service=$service" }

  $opt{AutoCommit}          //= 1;
  $opt{AutoInactiveDestroy} //= 1;
  $opt{PrintError}          //= 0;
  $opt{RaiseError}          //= 1;

  return $dsn, @userinfo[0, 1], \%opt;
}

sub _dsn_for_mysql {
  my $self = shift;
  my $url  = $self->url;
  my %opt  = %{$url->query->to_hash};
  my $dsn  = "dbi:mysql:dbname=$self->{database_name}";
  my @userinfo;

  if (my $host = $url->host) { $dsn .= ";host=$host" }
  if (my $port = $url->port) { $dsn .= ";port=$port" }
  if (($url->userinfo // '') =~ /^([^:]+)(?::([^:]+))?$/) { @userinfo = ($1, $2) }

  $opt{AutoCommit}          //= 1;
  $opt{AutoInactiveDestroy} //= 1;
  $opt{PrintError}          //= 0;
  $opt{RaiseError}          //= 1;
  $opt{mysql_enable_utf8}   //= 1;

  return $dsn, @userinfo[0, 1], \%opt;
}

sub _generate_database_name {
  my ($self, $n) = @_;
  my @name = (Sys::Hostname::hostname, $<, File::Basename::basename($0));

  push @name, $n if $n > 0;
  return join '-', map { s!\W!_!g; $_ } @name;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
