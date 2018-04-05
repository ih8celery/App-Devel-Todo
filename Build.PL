#! /usr/bin/env perl
#
# file: Build.PL
# author: Adam Marshall (ih8celery)
# brief: build the todo-app project

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  dist_version  => '0.01',
  dist_abstract => 'META.yml',
  module_name   => 'App::Devel::Todo',
  install_path  => { conf => "$ENV{HOME}/bin" },
  requires      => {
    'Getopt::Long' => '2.5',
    'Cwd'          => '0',
    'YAML::XS'     => '0'
  },
  license       => 'MIT'
);

$build->create_build_script;
