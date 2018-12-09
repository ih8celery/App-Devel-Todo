#!/usr/bin/env perl

package Project::Utils::Taggable;

use Mouse::Role;
requires qw/tag untag has_tag/;
