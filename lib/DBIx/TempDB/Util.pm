package DBIx::TempDB::Util;
use strict;
use warnings;
use Exporter 'import';

use Carp qw(confess croak);
use Scalar::Util 'blessed';
use URI::db;
use URI::QueryParam;

our @EXPORT_OK = qw(dsn_for parse_sql);

sub dsn_for {
  my ($url, $database_name) = @_;
  $url = URI::db->new($url) unless blessed $url;
  croak "Unknown engine for $url" unless $url->has_recognized_engine;

  my $engine = $url->canonical_engine;
  $database_name //= $url->dbname;
  return _dsn_for_mysql($url, $database_name)  if $engine eq 'mysql';
  return _dsn_for_pg($url, $database_name)     if $engine eq 'pg';
  return _dsn_for_sqlite($url, $database_name) if $engine eq 'sqlite';
  croak "Can't create DSN for engine $engine.";
}

sub parse_sql {
  my ($type, $sql) = @_;
  $type = $type->canonical_engine if blessed $type;
  return _parse_mysql($sql) if $type eq 'mysql';
  return $sql;
}

sub _dsn_for_mysql {
  my ($url, $database_name) = @_;
  my %opt = %{$url->query_form_hash};
  my ($dsn, @userinfo);

  $url = URI::db->new($url);
  $url->dbname($database_name);
  $url->query(undef);
  $dsn      = $url->dbi_dsn;
  @userinfo = ($url->user, $url->password);

  $opt{AutoCommit}          //= 1;
  $opt{AutoInactiveDestroy} //= 1;
  $opt{PrintError}          //= 0;
  $opt{RaiseError}          //= 1;
  $opt{mysql_enable_utf8}   //= 1;

  return $dsn, @userinfo[0, 1], \%opt;
}

sub _dsn_for_pg {
  my ($url, $database_name) = @_;
  my %opt = %{$url->query_form_hash};
  my ($dsn, @userinfo);

  $url = URI::db->new($url);
  $url->dbname($database_name);
  $url->query(undef);
  if (my $service = delete $opt{service}) { $url->query_param(service => $service) }
  $dsn      = $url->dbi_dsn;
  @userinfo = ($url->user, $url->password);

  $opt{AutoCommit}          //= 1;
  $opt{AutoInactiveDestroy} //= 1;
  $opt{PrintError}          //= 0;
  $opt{RaiseError}          //= 1;

  return $dsn, @userinfo[0, 1], \%opt;
}

sub _dsn_for_sqlite {
  my ($url, $database_name) = @_;
  my %opt = %{$url->query_form_hash};

  $url = URI::db->new($url);
  $url->dbname($database_name);
  $url->query(undef);
  my $dsn = $url->dbi_dsn;

  $opt{AutoCommit}          //= 1;
  $opt{AutoInactiveDestroy} //= 1;
  $opt{PrintError}          //= 0;
  $opt{RaiseError}          //= 1;
  $opt{sqlite_unicode}      //= 1;

  return $dsn, "", "", \%opt;
}

sub _parse_mysql {
  my $sql = shift;
  my ($new, $last, $delimiter) = (0, '', ';');
  my @commands;

  while (length($sql) > 0) {
    my $token;

    if ($sql =~ /^$delimiter/x) {
      ($new, $token) = (1, $delimiter);
    }
    elsif ($sql =~ /^delimiter\s+(\S+)\s*(?:\n|\z)/ip) {
      ($new, $token, $delimiter) = (1, ${^MATCH}, $1);
    }
    elsif ($sql =~ /^(\s+)/s or $sql =~ /^(\w+)/) {    # general name
      $token = $1;
    }
    elsif (
      $sql    =~ /^--.*(?:\n|\z)/p                             # double-dash comment
      or $sql =~ /^\#.*(?:\n|\z)/p                             # hash comment
      or $sql =~ /^\/\*(?:[^\*]|\*[^\/])*(?:\*\/|\*\z|\z)/p    # C-style comment
      or $sql =~ /^'(?:[^'\\]*|\\(?:.|\n)|'')*(?:'|\z)/p       # single-quoted literal text
      or $sql =~ /^"(?:[^"\\]*|\\(?:.|\n)|"")*(?:"|\z)/p       # double-quoted literal text
      or $sql =~ /^`(?:[^`]*|``)*(?:`|\z)/p
      )
    {                                                          # schema-quoted literal text
      $token = ${^MATCH};
    }
    else {
      $token = substr($sql, 0, 1);
    }

    # chew token
    substr $sql, 0, length($token), '';

    if ($new) {
      push @commands, $last if $last !~ /^\s*$/s;
      ($new, $last) = (0, '');
    }
    else {
      $last .= $token;
    }
  }

  push @commands, $last if $last !~ /^\s*$/s;
  return map { s/^\s+//; $_ } @commands;
}

1;

=encoding utf8

=head1 NAME

DBIx::TempDB::Util - Utility functions for DBIx::TempDB

=head1 SYNOPSIS

  use DBIx::TempDB::Util qw(dsn_for parse_sql);

  print $_ for parse_sql("mysql", "delimiter //\ncreate table y (bar varchar(255))//\n");

  my $url = URI::db->new("postgresql://postgres@localhost");
  print join ", ", dsn_for($url);

=head1 DESCRIPTION

L<DBIx::TempDB::Util> contains some utility functions for L<DBIx::TempDB>.

=head1 FUNCTIONS

=head2 dsn_for

  @dsn = dsn_for +URI::db->new("postgresql://postgres@localhost");
  @dsn = dsn_for "postgresql://postgres@localhost";

L</dsn_for> takes either a string or L<URI::db> object and returns a list of
arguments suitable for L<DBI/connect>.

=head2 parse_sql

  @statements = parse_sql $type, $sql;
  @statements = parse_sql $uri_db, $sql;
  @statements = parse_sql "mysql", "insert into ...";

Takes either a string or an L<URI::db> object and a string containing SQL and
splits the SQL into a list of individual statements.

Currently only "mysql" is a supported type, meaning any other type will simply
return the input C<$sql>.

This is not required for SQLite though, you can do this instead:

  local $dbh->{sqlite_allow_multiple_statements} = 1;
  $dbh->do($sql);

=head1 SEE ALSO

L<DBIx::TempDB>.

=cut
