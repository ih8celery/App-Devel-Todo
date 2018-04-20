#! /usr/bin/env perl
#
# file: Build.PL
# author: Adam Marshall (ih8celery)
# brief: build the todo-app project

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  dist_version   => '0.005000',
  dist_abstract  => 'META.yml',
  dist_author    => 'Adam Marshall',
  module_name    => 'App::Devel::Todo',
  requires       => {
    'Getopt::Long' => '>2.24',
    'Cwd'          => '0',
    'YAML::XS'     => '0'
  },
  build_requires => {
    'Module::Build' => '>0.2'
  },
  test_requires  => {
    'Test::More' => '>0.9',
    'YAML::XS'   => '0'
  },
  create_license => 1,
  license        => 'mit'
);

$build->create_build_script;
