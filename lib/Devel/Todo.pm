#! /usr/bin/env perl
# file: Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: define Devel::Todo class

package Devel::Todo;

use strict;
use warnings;

use feature qw/say/;

use YAML::XS qw/LoadFile DumpFile Dump/;

our $VERSION = '0.006000';

# construct a new Devel::Todo object
sub new {
  my ($n_class, $n_todo_file, $n_config) = @_;

  my $n_self = {
    TODO_FILE => $n_todo_file,
    PROJECT   => LoadFile($n_todo_file),
    SETTINGS  => {
      STATUS              => ($n_config->{STATUS}
          || die "no status given"),
      DEFAULT_STATUS      => ($n_config->{DEFAULT_STATUS}
          || die "no default status given"),
      DEFAULT_PRIORITY    => $n_config->{DEFAULT_PRIORITY} || 0,
      DEFAULT_DESCRIPTION => $n_config->{DEFAULT_DESCRIPTION} || '',
      STATUS_OPT          => $n_config->{STATUS_OPT} || '',
      PRIORITY_OPT        => $n_config->{PRIORITY_OPT} || '',
      DESCRIPTION_OPT     => $n_config->{DESCRIPTION_OPT} || '',
      MOVE_ENABLED        => $n_config->{MOVE_ENABLED} || 1,
    },
  };

  bless $n_self, $n_class;
}

# does list item have a status?
sub _has_the_status {
  my ($elem, $cmp_status, $status, $default_status) = @_;

  return 1 if ($status eq 'all');

  if (ref($elem) eq "HASH") {
    if (exists $elem->{status} && defined $elem->{status}) {
      return ($cmp_status eq $elem->{status});
    }
    else {
      return ($default_status eq $cmp_status);
    }
  }
  else {
    return ($cmp_status eq $elem);
  }
}

# does todo list have item named after key?
sub has_elem {
  my ($he_self, $he_key) = @_;

  return (exists $he_self->{PROJECT}{contents}{$he_key});
}

# does todo list have a sublist with an item named after key
sub has_sublist_elem {
  my ($hse_self, $hse_subkey, $hse_key) = @_;
  my $hse_list = $hse_self->{PROJECT}{contents};

  return (exists $hse_list->{$hse_subkey}
        && exists $hse_list->{$hse_subkey}{$hse_key});
}

# is scalar a todo list?
sub isa_list {
  my ($val) = @_;

  return (ref($val) eq 'HASH' && exists $val->{contents}
    && ref($val->{contents}) eq 'HASH');
}

# create an item or maybe change an existing one
sub Add_Element {
  my ($ae_self, $ae_args) = @_;

  if ($ae_self->{SETTINGS}{STATUS} eq 'all') {
    die("error: cannot create with \'all\' status");
  }

  my $ae_item = _ae_maker($ae_self->{SETTINGS});
  for (@$ae_args) {
    if ($ae_self->{SETTINGS}{MOVE_ENABLED}
      && $ae_self->apply_to_matches(\&_ae_mover, $_)) {

      next;
    }
    elsif (ref($_) eq 'ARRAY') {
      my $ae_sublist = $ae_self->{PROJECT}{contents}{ $_->[0] };

      # make several items with identical attributes in a sublist
      for my $ae_item_name (@{ $_->[1] }) {
        $ae_sublist->{contents}{$ae_item_name} = $ae_item;
      }
    }
    else {
      $ae_self->{PROJECT}{contents}{$_} = $ae_item;
    }
  }

  DumpFile($ae_self->{TODO_FILE}, $ae_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by add_element to move an item
sub _ae_mover {
  my ($project, $settings, $key) = @_;

  if (ref($project->{contents}{$key}) eq 'HASH') {
    $project->{contents}{$key}{status} = $settings->{STATUS};
  }
  else {
    $project->{contents}{$key} = $settings->{STATUS};
  }
}

# create a new list item
sub _ae_maker {
  my ($settings) = @_;
  my $out = {};

  if ($settings->{PRIORITY_OPT} eq ''
    && $settings->{DESCRIPTION_OPT} eq '') {
    
    return $settings->{DEFAULT_STATUS}
        unless $settings->{STATUS_OPT} ne '';

    return $settings->{STATUS_OPT};
  }
  elsif ($settings->{PRIORITY_OPT} eq '') {
    $out->{description} = $settings->{DESCRIPTION_OPT};
  }
  elsif ($settings->{DESCRIPTION_OPT} eq '') {
    $out->{priority} = $settings->{PRIORITY_OPT};
  }
  elsif ($settings->{STATUS_OPT} ne '') {
    $out->{status} = $settings->{STATUS_OPT};
  }
  
  return $out;
}

# call a function on all relevant items
sub apply_to_matches {
  my ($atm_self, $atm_sub, $atm_key) = @_;

  if (ref($atm_key) eq 'ARRAY') {
    return 0 unless $atm_self->has_elem($atm_key->[0]);

    my $atm_count   = 0;
    my $atm_sublist = $atm_self->{PROJECT}{contents}{ $atm_key->[0] };

    if (isa_list($atm_sublist)) {
      foreach (@{ $atm_key->[1] }) {
        if ($atm_self->has_sublist_elem($atm_key->[0], $_)) {
          &{ $atm_sub }($atm_sublist, $atm_self->{SETTINGS}, $atm_key);
        }
      }

      return $atm_count;
    }
  }
  elsif ($atm_self->has_elem($atm_key)) {
    &{ $atm_sub }($atm_self->{PROJECT}, $atm_self->{SETTINGS}, $atm_key);
    
    return 1;
  }

  return 0;
}

# change relevant items 
sub Edit_Element {
  my ($ee_self, $ee_args) = @_;
  
  unless (isa_list($ee_self->{PROJECT})) {
    die('error: no todo list to work on');
  }

  if ($ee_self->{SETTINGS}{STATUS} eq 'all') {
    die("error: cannot edit with \'all\' status");
  }

  foreach (@$ee_args) {
    $ee_self->apply_to_matches(\&_ee_set_attrs, $_);
  }

  DumpFile($ee_self->{TODO_FILE}, $ee_self->{SETTINGS}, $ee_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by edit_element to change items
sub _ee_set_attrs {
  my ($list, $settings, $key) = @_;

  my $contents = $list->{contents};

  return if ($settings->{STATUS_OPT} eq '' 
          && $settings->{PRIORITY_OPT} eq ''
          && $settings->{DESCRIPTION_OPT} eq '');

  my $replacement = {};

  if (ref($contents->{$key}) eq 'HASH') {
    $replacement = $contents->{$key};
  }
  
  if ($settings->{STATUS_OPT} ne '') {
    $replacement->{status} = $settings->{STATUS_OPT};
  }

  if ($settings->{PRIORITY_OPT} ne '') {
    $replacement->{priority} = $settings->{PRIORITY_OPT};
  }

  if ($settings->{DESCRIPTION_OPT} ne '') {
    $replacement->{description} = $settings->{DESCRIPTION_OPT};
  }

  $contents->{$key} = $replacement;
}

# print information about items in list
sub Show_Element {
  my ($se_self, $se_args) = @_;

  die('error: nothing to show') unless (isa_list($se_self->{PROJECT}));

  if (scalar @$se_args) {
    foreach (@$se_args) {
      # ignore arrayref args
      if (ref($_) eq '') {
        $se_self->apply_to_matches(\&_se_dumper, $_);
      }
    }
  }
  else {
    _se_dumper($se_self->{PROJECT}, $se_self->{SETTINGS}, '');
  }

  return 0;
}

# print contents of 'list' if items have the right status
sub _se_dumper {
  my ($project, $settings, $key) = @_;

  my $has_printed_key = 0;
  $has_printed_key    = 1 if $key eq '';

  if ($key eq '') {
    # print each item, excluding sublists, if it has the right status
    # apply the same rule to the ITEMS of a sublist
    while ((my ($k, $v) = each %{ $project->{contents} })) {
      if (isa_list($v)) {
        _se_dumper($project, $settings, $k);
      }
      elsif (_has_the_status(
                $v,
                $settings->{STATUS},
                $settings->{STATUS},
                $settings->{DEFAULT_STATUS})) {

        say $k; # TODO show more information, i.e. attributes
      }
    }
  }
  else { 
    my $sublist = $project->{contents}{$key};

    return unless isa_list($sublist);

    while ((my ($k, $v) = each %{ $sublist->{contents} })) {
      if (_has_the_status(
              $v,
              $settings->{STATUS},
              $settings->{STATUS},
              $settings->{DEFAULT_STATUS})) {

        unless ($has_printed_key) {
          say $key, ':';

          $has_printed_key = 1;
        }

        say '  ', $k; # TODO show more information, i.e. attributes
      }
    }
  }
}

# remove relevant items
sub Delete_Element {
  my ($de_self, $de_args) = @_;

  die('error: nothing to delete') unless isa_list($de_self->{PROJECT});

  my $de_contents = $de_self->{PROJECT}{contents};
  if (scalar @$de_args) {
    foreach (@$de_args) {
      $de_self->apply_to_matches(\&_de_deleter, $_);
    }
  }
  else {
    for my $key (keys %{$de_contents}) {
      if (_has_the_status(
              $de_contents->{$key},
              $de_self->{SETTINGS}{STATUS},
              $de_self->{SETTINGS}{STATUS},
              $de_self->{SETTINGS}{DEFAULT_STATUS})) {

        delete $de_contents->{$key};
      }
      elsif (isa_list($de_contents->{$key})) {
        while ((my ($subkey, $subvalue) = each %{ $de_contents->{$key}{contents} })) {
          _de_deleter($de_contents->{$key}, $de_self->{SETTINGS}, $subkey);
        }
      }
    }
  }

  DumpFile($de_self->{TODO_FILE}, $de_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by delete_element to remove an item
sub _de_deleter {
  my ($project, $settings, $key) = @_;

  if (_has_the_status(
          $project->{contents}{$key},
          $settings->{STATUS},
          $settings->{STATUS},
          $settings->{DEFAULT_STATUS})) {

    delete $project->{contents}{ $key };
  }
}
