#!/usr/bin/env perl

package Project::Utils::Describable;

use Mouse::Role;
requires qw/name summary info/;
