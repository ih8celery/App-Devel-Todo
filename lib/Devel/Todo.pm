#! /usr/bin/env perl
# file: Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: define Devel::Todo class

package Devel::Todo;

use strict;
use warnings;

use feature qw/say/;

use File::Spec::Functions;
use YAML::XS qw/LoadFile DumpFile/;

# actions the app may take upon the selected items
package Action {
  our $DELETE = 0; # remove a todo
  our $CREATE = 1; # insert a todo
  our $EDIT   = 2; # change the contents of an item
  our $SHOW   = 3; # print information about items
}

# config variables always relevant to the program
our $VERSION      = '0.05';
our $CONFIG_FILE  = "$ENV{HOME}/.todorc.yml";
our $TODO_FILE    = '';

# the general action which will be taken by the program
our $ACTION = $Action::CREATE;

# status selected by the subcommand
our $STATUS = 'do';

# default attributes
our $DEFAULT_STATUS      = 'do';
our $DEFAULT_PRIORITY    = 0;
our $DEFAULT_DESCRIPTION = '';

# attributes given on the command line
our $STATUS_OPT;
our $PRIORITY_OPT;
our $DESCRIPTION_OPT;

# before creating a new todo, an old one that matches may be moved
our $MOVE_ENABLED = 1;

# does list item have a status?
sub _has_the_status {
  my ($item, $status) = @_;

  return 1 if ($STATUS eq 'all');

  if (ref($item) eq "HASH") {
    if (exists $item->{status} && defined $item->{status}) {
      return ($status eq $item->{status});
    }
    else {
      return ($DEFAULT_STATUS eq $status);
    }
  }
  else {
    return ($status eq $item);
  }
}

# does todo list have item named after key?
sub has_elem {
  my ($project, $key) = @_;

  return (exists $project->{contents}{$key});
}

# is scalar a todo list?
sub isa_todo_list {
  my ($val) = @_;

  return (ref($val) eq 'HASH' && exists $val->{contents}
    && ref($val->{contents}) eq 'HASH');
}

# create an item or maybe change an existing one
sub Add_Element {
  my ($ae_file, $ae_project, $ae_args) = @_;

  _error("cannot create with \'all\' status") if ($STATUS eq 'all');

  my $ae_item = _ae_maker();
  for (@$ae_args) {
    if ($MOVE_ENABLED
      && _apply_to_matches(\&_ae_mover, $ae_project, $_)) {

      next;
    }
    elsif (ref($_) eq 'ARRAY') {
      my $ae_sublist = $ae_project->{contents}{ $_->[0] };

      # make several items with identical values in a sublist
      for my $ae_item_name (@{ $_->[1] }) {
        $ae_sublist->{contents}{$ae_item_name} = $ae_item;
      }
    }
    else {
      # make one item using $STATUS_OPT, $PRIORITY_OPT, $DESCRIPTION_OPT
      $ae_project->{contents}{$_} = $ae_item;
    }
  }

  DumpFile($ae_file, $ae_project);

  return 0;
}

# passed to _apply_to_matches by add_element to move an item
sub _ae_mover {
  my ($project, $key) = @_;

  if (ref($project->{contents}{$key}) eq 'HASH') {
    $project->{contents}{$key}{status} = $STATUS;
  }
  else {
    $project->{contents}{$key} = $STATUS;
  }
}

# create a new list item
sub _ae_maker {
  my $out = {};

  if (!defined($PRIORITY_OPT) && !defined($DESCRIPTION_OPT)) {
    return $DEFAULT_STATUS unless defined $STATUS_OPT;

    return $STATUS_OPT;
  }
  elsif (!defined($PRIORITY_OPT)) {
    $out->{description} = $DESCRIPTION_OPT;
  }
  elsif (!defined($DESCRIPTION_OPT)) {
    $out->{priority} = $PRIORITY_OPT;
  }
  else {
    $out->{status} = $STATUS_OPT if defined $STATUS_OPT;
  }
  
  return $out;
}

# call a function on all relevant items
sub _apply_to_matches {
  my $sub   = shift;
  my $start = shift;
  my $key   = shift;

  if (ref($key) eq 'ARRAY') {
    return 0 unless has_elem($start, $key->[0]);

    my $count   = 0;
    my $sublist = $start->{contents}{ $key->[0] };

    if (isa_todo_list($sublist)) {
      foreach ($key->[1]) {
        $count += _apply_to_matches($sub, $sublist, $_);
      }

      return $count;
    }
    else {
      return 0;
    }
  }
  else {
    return 0 unless has_elem($start, $key);

    &{ $sub }($start, $key);
  }

  return 1;
}

# change relevant items 
sub Edit_Element {
  my ($ee_file, $ee_project, $ee_args) = @_;
  
  _error('list must have contents') unless (isa_todo_list($ee_project));
  _error('cannot edit with \'all\' status') if ($STATUS eq 'all');

  foreach (@$ee_args) {
    _apply_to_matches(\&_ee_set_attrs, $ee_project, $_);
  }

  DumpFile($ee_file, $ee_project);

  return 0;
}

# passed to _apply_to_matches by edit_element to change items
sub _ee_set_attrs {
  my ($list, $key) = @_;

  my $contents = $list->{contents};

  return unless (defined $STATUS_OPT 
    || defined $PRIORITY_OPT || defined $DESCRIPTION_OPT);

  my $replacement = {};

  if (ref($contents->{$key}) eq 'HASH') {
    $replacement = $contents->{$key};
  }
  
  if (defined $STATUS_OPT) {
    $replacement->{status} = $STATUS_OPT;
  }

  if (defined $PRIORITY_OPT) {
    $replacement->{priority} = $PRIORITY_OPT;
  }

  if (defined $DESCRIPTION_OPT) {
    $replacement->{description} = $DESCRIPTION_OPT;
  }

  $contents->{$key} = $replacement;
}

# print information about items in list
sub Show_Element {
  my ($se_project, $se_args) = @_;

  _error('nothing to show') unless (isa_todo_list($se_project));

  if (scalar @$se_args) {
    foreach (@$se_args) {
      # ignore arrayref args
      if (ref($_) eq '') {
        _apply_to_matches(\&_se_dumper, $se_project, $_);
      }
    }
  }
  else {
    _se_dumper($se_project, '');
  }

  return 0;
}

# print contents of 'list' if items have the right status
sub _se_dumper {
  my $project = shift;
  my $key     = shift;

  my $has_printed_key = 0;
  $has_printed_key    = 1 if $key eq '';

  if ($key eq '') {
    # print each item, excluding sublists, if it has the right status
    # apply the same rule to the ITEMS of a sublist
    while ((my ($k, $v) = each %{ $project->{contents} })) {
      if (isa_todo_list($v)) {
        _se_dumper($project, $k);
      }
      elsif (_has_the_status($v, $STATUS)) {
        say $k; # TODO show more information about todo, i.e. attributes
      }
    }
  }
  else { 
    my $sublist = $project->{contents}{$key};

    return unless isa_todo_list($sublist);

    while ((my ($k, $v) = each %{ $sublist->{contents} })) {
      if (_has_the_status($v, $STATUS)) {
        unless ($has_printed_key) {
          say $key, ':';

          $has_printed_key = 1;
        }

        say '  ', $k; # TODO show more information about todo, i.e. attributes
      }
    }
  }
}

# remove relevant items
sub Delete_Element {
  my ($de_file, $de_data, $de_args) = @_;

  _error('nothing to delete') unless (isa_todo_list($de_data));

  my $de_contents = $de_data->{contents};
  if (scalar @$de_args) {
    foreach (@$de_args) {
      _apply_to_matches(\&_de_deleter, $de_data, $_);
    }
  }
  else {
    for my $key (keys %{$de_contents}) {
      if (_has_the_status($de_contents->{$key}, $STATUS)) {
        delete $de_contents->{$key};
      }
      elsif (isa_todo_list($de_contents->{$key})) {
        while ((my ($subkey, $subvalue) = each %{ $de_contents->{$key}{contents} })) {
          _de_deleter($de_contents->{$key}, $subkey);
        }
      }
    }
  }

  DumpFile($de_file, $de_data);

  return 0;
}

# passed to _apply_to_matches by delete_element to remove an item
sub _de_deleter {
  my ($project, $key) = @_;

  if (_has_the_status($project->{contents}{$key}, $STATUS)) {
    delete $project->{contents}{ $key };
  }
}