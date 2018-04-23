#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;

use Devel::Todo;

plan tests => 6;

my ($fh, $file) = tempfile();
close $fh;

my $yaml = {
  name     => 'today',
  contents => {
    'eat'   => {
      status => 'do'
    },
    'sleep' => 'want',
  },
};

DumpFile($file, $yaml);

my $conf = {
    STATUS              => 'do',
    MOVE_ENABLED        => 1,
    STATUS_OPT          => '',
    PRIORITY_OPT        => 1,
    DESCRIPTION_OPT     => 'good food',
    DEFAULT_STATUS      => 'do',
    DEFAULT_PRIORITY    => 0,
    DEFAULT_DESCRIPTION => '',
    VERBOSE             => 0,
};

my $todos = Devel::Todo->new($file, $conf);

my $attrs1 = $todos->get_attributes('eat');

ok($attrs1->{status} eq 'do', 'status initially do');

ok(!defined($attrs1->{priority}), 'priority not defined');

ok(!defined($attrs1->{description}), 'description not defined');

$todos->Edit_Element(['eat']);

my $attrs2 = $todos->get_attributes('eat');

is($attrs2->{status}, 'do', 'status still do');

is($attrs2->{priority}, 1, 'edit priority of eating to 0');

is($attrs2->{description}, 'good food', 'edit description of eating');

done_testing();
