#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use YAML::XS qw/DumpFile/;
use File::Temp qw/tempfile/;
use Test::Output;

use Devel::Todo;

plan tests => 4;

my ($fh, $file) = tempfile();
close $fh;

# for showing entire list
my $yaml1 = {
  name => 'today',
  contents => {
    sleep => 'do',
  }
};

# for showing list verbosely
my $yaml2 = {
  name     => 'today',
  contents => {
    eat => {
      status      => 'do',
      description => 'I am hungry'
    }
  }
};

# showing only part of list with desired status
my $yaml3 = {
  name => 'today',
  contents => {
    eat   => 'want',
    sleep => 'do',
  }
};

# for showing a sublist
my $yaml4 = {
  name     => 'today',
  contents => {
    eat           => 'do',
    'Devel::Todo' => {
      contents    => {
        'test' => 'do',
      },
    },
  },
};

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

sub write1 {
  DumpFile($file, $yaml1);
  Devel::Todo->new($file, $conf)->Show_Element([]);
}

stdout_is(\&write1,
  "sleep\n",
  'show entire list');

sub write2 {
  DumpFile($file, $yaml2);
  $conf->{VERBOSE} = 1;
  Devel::Todo->new($file, $conf)->Show_Element([]);
  $conf->{VERBOSE} = 0;
}

stdout_is(\&write2,
  "eat (I am hungry)\n",
  'show entire list verbosely');

sub write3 {
  DumpFile($file, $yaml3);
  Devel::Todo->new($file, $conf)->Show_Element([]);
}

stdout_is(\&write3,
  "sleep\n",
  'show only part of list with status do');

sub write4 {
  DumpFile($file, $yaml4);
  Devel::Todo->new($file, $conf)->Show_Element(['Devel::Todo']);
}

stdout_is(\&write4,
  "Devel::Todo:\n  test\n",
  'show only sublist Devel::Todo');

done_testing();
