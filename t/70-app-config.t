#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp qw/tempfile/;
use YAML::XS qw/LoadFile DumpFile/;

use App::Devel::Todo qw/:tests/;

plan tests => 8;

{
  local @ARGV = ("do", "sleep", "eat", "code.", "docs", "tests");

  # get a potential subcommand
  my ($sub, $result1) = get_possible_subcommand();

  is($sub, "do", 'do is possible subcommand');

  ok(scalar @ARGV == 5, 'getting subcommand shifts @ARGV');

  # process args
  my ($args, $result2) = process_args();
  is_deeply($args, [
      "sleep",
      "eat",
      [ "code", [ "docs", "tests" ] ]
    ], 'process remaining args into array reference');

  # configure the app from file
  my $stati = {
    'do'   => 1,
    'did'  => 1,
    'want' => 1,
  };

  my ($fh, $file) = tempfile();
  close $fh;

  my $yaml = {
    verbose  => 1,
    statuses => {
      'maybe' => 'consider doing this later'
    },
  };

  DumpFile($file, $yaml);

  ok(scalar keys %$stati == 3, 'three statuses initially defined');

  my ($result3, $defaults) = configure_app($file, $stati);

  ok($result3 == 1, 'configure succeeded');
  ok($defaults->{verbose} == 1, 'default verbosity set');
  ok(scalar keys %$stati == 4, 'defined another status');
  is($stati->{maybe}, 'consider doing this later', 'maybe status defined');
}

done_testing();
