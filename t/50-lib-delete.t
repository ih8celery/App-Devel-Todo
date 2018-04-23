#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;

use Devel::Todo;

plan tests => 16;

my ($fh, $file) = tempfile();

my $yaml = {
  name     => 'today',
  contents => {
    'eat'   => 'do',
    'sleep' => 'want',
    'bathe'  => 'do',
    'code'  => {
      contents => {
        'test'   => 'do',
        'doc'    => 'did',
        'review' => 'do'
      }
    },
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

ok($todos->has_element('eat'), 'has element named eat');

$todos->Delete_Element(['eat']);
ok(!$todos->has_element('eat'), 'deleted element named eat');

ok($todos->has_element('sleep'), 'has element named sleep');

$todos->Delete_Element(['sleep']);
ok($todos->has_element('sleep'), 'still has element named sleep');
note('an element will not be deleted if its status is mismatched');

ok($todos->has_element('code', 'review'), 'has sublist element named review');

$todos->Delete_Element([ ['code', ['review'] ] ]);
ok(!$todos->has_element('code', 'review'), 'deleted review');

ok($todos->has_element('code', 'doc'), 'code sublist has element doc');
ok($todos->has_element('code', 'test'), 'code sublist has element test');

$todos->Delete_Element(['code']);
ok(!$todos->has_element('code', 'test'),
  'deleting sublist deleted test element');

ok($todos->has_element('code', 'doc'),
  'deleting sublist does not affect elements with mismatched status');

ok($todos->has_element('bathe'), 'list has bath element');
ok($todos->has_element('code'), 'list has code sublist');
ok($todos->has_element('sleep'), 'list has sleep element');

$todos->Delete_Element([]);

ok(!$todos->has_element('bathe'), 'element named bathe deleted');
ok($todos->has_element('sleep'), 'element named sleep unaffected by delete');
ok($todos->has_element('code'), 'sublist code unaffected by delete or rest of list');

done_testing();
