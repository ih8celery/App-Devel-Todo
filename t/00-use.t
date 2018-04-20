#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { plan tests => 2 };
BEGIN { use_ok('App::Devel::Todo'); };
BEGIN { use_ok('Devel::Todo'); };

done_testing();
