#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;
use Test::Output;

use Devel::Todo;

plan tests => 5;

my ($fh, $file) = tempfile();

my $yaml = {
  name     => 'today',
  contents => {
    'eat'   => 'do',
    'sleep' => 'want',
    'code'  => {
      contents => {
        'doc' => 'do'
      }
    }
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

ok(!$todos->has_element('EAT'), 'does not have element named EAT');

ok($todos->has_sublist_element('code', 'doc'), 'sublist code has element doc');

ok(!$todos->has_sublist_element('code', 'test'), 'sublist code does not have element test');

sub write_uc {
  print uc($_[2]), "\n";
}

sub test1 {
  $todos->apply_to_matches(\&write_uc, 'eat');
}

stdout_is(\&test1, "EAT\n", 'custom sub passed to apply_to_matches capitalizes key');

done_testing();
