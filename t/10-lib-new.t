#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;

use Devel::Todo;

plan tests => 1;

my ($fh, $file) = tempfile();

my $yaml = {
  name     => 'today',
  contents => {
    'eat'   => 'do',
    'sleep' => 'want',
  },
};

DumpFile($file, $yaml);

my $conf = {
    STATUS              => 'do',
    MOVE_ENABLED        => 1,
    STATUS_OPT          => '',
    PRIORITY_OPT        => '',
    DESCRIPTION_OPT     => '',
    DEFAULT_STATUS      => 'do',
    DEFAULT_PRIORITY    => 0,
    DEFAULT_DESCRIPTION => '',
    VERBOSE             => 0,
};

my $todos = Devel::Todo->new($file, $conf);

isa_ok($todos, 'Devel::Todo');

close($fh);

done_testing();
