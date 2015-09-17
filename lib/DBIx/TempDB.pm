package DBIx::TempDB;

=head1 NAME

DBIx::TempDB - Create a temporary database

=head1 VERSION

0.02

=head1 SYNOPSIS

  use Test::More;
  use DBIx::TempDB;
  use DBI;

  # create a temp database
  my $tmpdb = DBIx::TempDB->new("postgresql://postgres@localhost");

  # print complete url to db server with database name
  diag $tmpdb->url;

  # useful for reading in fixtures
  $tmpdb->execute("create table users (name text)");
  $tmpdb->execute_file("path/to/file.sql");

  # connect to the temp database
  my $db = DBI->connect($tmpdb->dsn);

  # run tests...

  done_testing;
  # database is cleaned up when test exit

=head1 DESCRIPTION

L<DBIx::TempDB> is a module which allows you to create a temporary database,
which only lives as long as your process is alive. This can be very
convenient when you want to run tests in parallel, without messing up the
state between tests.

This module currently support PostgreSQL and MySQL by installing the optional
modules L<DBD::Pg> and/or L<DBD::mysql>. Let me know if you want another
database to be supported.

This module is currently EXPERIMENTAL. That means that if any major design
flaws have been made, they will be fixed without warning.

=cut

use strict;
use warnings;
use Carp 'confess';
use Cwd ();
use DBI;
use File::Basename ();
use File::Spec;
use Mojo::URL;    # because I can't figure out how to use URI.pm
use Sys::Hostname ();

use constant CWD => eval { File::Basename::dirname(Cwd::abs_path($0)) };
use constant MAX_NUMBER_OF_TRIES => $ENV{TEMP_DB_MAX_NUMBER_OF_TRIES} || 20;

our $VERSION = '0.02';

our %SCHEMA_DATABASE = (postgresql => 'postgres', mysql => 'mysql');

=head1 METHODS

=head2 create_database

  $self = $self->create_database;

This method will create a temp database for the current process. Calling this
method multiple times will simply do nothing. This method is normally
automatically called by L</new>.

This method will also set C<DBIX_TEMP_DB_URL> to a URL suited for modules
such as L<Mojo::Pg> and L<Mojo::mysql>.

The database name generated is subject to change, but currently it looks like
something like this: C<tmp_${UID}_${0}_${HOSTNAME}>.

=cut

sub create_database {
  return $_[0] if $_[0]->{created};

  my $self = shift;
  my $dbh  = DBI->connect($self->_schema_dsn);
  my ($guard, $name);

  local $@;
  while (++$guard < MAX_NUMBER_OF_TRIES) {
    $name = $self->_generate_database_name($guard);
    eval { $dbh->do("create database $name") } or next;
    $self->{created}++;
    $self->{database_name} = $name;
    $self->{url}->path($name);
    $ENV{DBIX_TEMP_DB_URL} = $self->{url}->to_string;
    return $self;
  }

  confess "Could not create unique database: '$name'. $@";
}

=head2 dsn

  ($dsn, $user, $pass, $attrs) = $self->dsn;
  ($dsn, $user, $pass, $attrs) = DBIx::TempDB->dsn($url);

Will parse L</url> or C<$url>, and return a list of arguments suitable for
L<DBI/connect>.

Note that this method cannot be called as an object method before
L</create_database> is called. You can on the other hand call it as a class
method, with an L<Mojo::URL> or URL string as input.

=cut

sub dsn {
  my ($self, $url) = @_;

  if (!ref $self and $url) {
    $url = Mojo::URL->new($url) unless ref $url;
    $self->can(sprintf '_dsn_for_%s', $url->scheme)->($self, $url, $url->path->parts->[0]);
  }
  else {
    confess 'Cannot return DSN before create_database() is called.' unless $self->{database_name};
    $self->can(sprintf '_dsn_for_%s', $self->url->scheme)->($self, $self->url, $self->{database_name});
  }
}

=head2 execute

  $self = $self->execute($sql);

This method will execute the given C<$sql> statements in the temporary
SQL server.

=cut

sub execute {
  my ($self, $sql) = @_;
  my $dbh = DBI->connect($self->dsn);
  my $sth = $dbh->prepare($sql);
  $sth->execute;
  $self;
}

=head2 execute_file

  $self = $self->execute_file("relative/to/executable.sql");
  $self = $self->execute_file("/absolute/path/stmt.sql");

This method will read the contents of a file and execute the SQL statements
in the temporary server.

This method is a thin wrapper around L</execute>.

=cut

sub execute_file {
  my ($self, $path) = @_;

  unless (File::Spec->file_name_is_absolute($path)) {
    confess "Cannot resolve absolute path to '$path'. Something went wrong with Cwd::abs_path($0)." unless CWD;
    $path = File::Spec->catfile(CWD, split '/', $path);
  }

  open my $SQL, '<', $path or die "DBIx::TempDB can't open $path: $!";
  my $ret = my $sql = '';
  while ($ret = $SQL->sysread(my $buffer, 131072, 0)) { $sql .= $buffer }
  die qq{DBIx::TempDB can't read from file "$path": $!} unless defined $ret;
  $self->execute($sql);
}

=head2 new

  $self = DBIx::TempDB->new($url, %args);
  $self = DBIx::TempDB->new("mysql://127.0.0.1");
  $self = DBIx::TempDB->new("postgresql://postgres@db.example.com");

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

  $self->{schema_database} ||= $SCHEMA_DATABASE{$url->scheme};

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

sub DESTROY { $_[0]->{created} and $_[0]->_cleanup }

sub _cleanup {
  my $self = shift;
  my $dbh  = DBI->connect($self->_schema_dsn);

  $dbh->do("drop database $self->{database_name}");
}

sub _dsn_for_postgresql {
  my ($class, $url, $database_name) = @_;
  my %opt = %{$url->query->to_hash};
  my $dsn = "dbi:Pg:dbname=$database_name";
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
  my ($class, $url, $database_name) = @_;
  my %opt = %{$url->query->to_hash};
  my $dsn = "dbi:mysql:dbname=$database_name";
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
  my @name = ('tmp', $<, File::Basename::basename($0), Sys::Hostname::hostname);

  push @name, $n if $n > 0;
  return join '_', map { s!\W!_!g; $_ } @name;
}

sub _schema_dsn {
  my $self = shift;
  local $self->{database_name} = $self->{schema_database};
  return $self->dsn;
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
