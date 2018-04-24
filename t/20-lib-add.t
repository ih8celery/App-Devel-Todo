#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;

use Devel::Todo;

plan tests => 3;

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

$todos->Add_Element(['code']);

ok($todos->has_element('code'), 'add code to todo list');

$todos->Add_Element(['test Devel::Todo', 'install Devel::Todo']);
ok($todos->has_element('test Devel::Todo')
  && $todos->has_element('install Devel::Todo'),
  'add two items at once to todo list');

$todos->Add_Element([ ['app', ['preview doc'] ] ]);
ok($todos->has_element('app', 'preview doc'),
  'create sublist with one element');

close($fh);

done_testing();
