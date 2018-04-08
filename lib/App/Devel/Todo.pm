#! /usr/bin/env perl
# file: App/Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: definitions of todo utility functions

package App::Devel::Todo;

use strict;
use warnings;

BEGIN {
  use Exporter;

  our @ISA = qw/Exporter/;
  our @EXPORT = qw{
    &configure_app &get_subcommand &get_args
    &find_project &create_stuff &edit_stuff
    &show_stuff &delete_stuff
    %OPTS
  };
}

use feature qw/say/;

use Const::Fast;
use Cwd qw/cwd/;
use File::Basename;
use YAML::XS qw/LoadFile DumpFile Dump/;

# actions the app may take upon the selected todos
package Action {
  use Const::Fast;

  const our $DELETE => 0; # remove a todo
  const our $CREATE => 1; # insert a todo
  const our $EDIT   => 2; # change the contents of a todo
  const our $SHOW   => 3; # print information about todo/s
}

# stati defined in a todos file
package Status {
  use Const::Fast;

  const our $TODO => "do";
  const our $DONE => "did";
  const our $WANT => "want";
}

# config variables always relevant to the program
our $VERSION      = '0.05';
our $CONFIG_FILE  = "$ENV{HOME}/.todorc";
our $TODO_FILE    = '';

# the general action which will be taken by the program
our $ACTION = $Action::CREATE;

# default attributes
our $DEFAULT_STATUS      = $Status::TODO;
our $DEFAULT_PRIORITY    = 0;
our $DEFAULT_DESCRIPTION = '';

# attributes given on the command line
our $STATUS      = '';
our $PRIORITY    = '';
our $DESCRIPTION = '';

# before creating a new todo, an old one that matches may be moved
our $MOVE_ENABLED = 1;

# declare command-line options
our %OPTS = (
  'help|h'              => \&_help,
  'version|v'           => \&_version,
  'delete|D'            => sub { $ACTION   = $Action::DELETE; },
  'create|C'            => sub { $ACTION   = $Action::CREATE; },
  'edit|E'              => sub { $ACTION   = $Action::EDIT; },
  'show|S'              => sub { $ACTION   = $Action::SHOW; },
  'create-no-move|N'    => sub { $ACTION = $Action::CREATE; $MOVE_ENABLED = 0; },
  'config-file|f=s'     => \$CONFIG_FILE,
  'todo-file|t=s'       => \$TODO_FILE,
  'use-status|s=s'      => \$STATUS,
  'use-priority|p=s'    => \$PRIORITY,
  'use-description|d=s' => \$DESCRIPTION
);

# print a help message appropriate to the situation and exit
sub _help {
  my $h_type = shift || 's';
  my $h_general_help = <<EOM;
Options:

-h|--help              print help
-v|--version           print application version information
-S|--show              print item/s from the currently selected list
-E|--edit              change list item information
-C|--create            add new item/s to selected list or move from another list
-N|--create-no-move    add new item/s to selected list without moving
-D|--delete            remove item/s from selected list
-f|--config-file=s     set global configuration file
-t|--todo-file=s       set project file
-s|--use-status=s      set the status used by some actions
-p|--use-priority=s    set the priority used by some actions
-d|--use-description=s set the description used by some actions 
EOM

  my %h_messages = (
    $Status::TODO => "selects your todo list",
    $Status::DONE => "selects your list of finished tasks",
    $Status::WANT => "selects your list of goals"
  );
  
  if ($h_type eq 'a') {
    # general help
    say $h_general_help;
  }
  else {
    # help with subcommand
    say $h_messages{$DEFAULT_STATUS};
  }

  exit 0;
}

# print the application name and version number and exit
sub _version {
  say "todo $VERSION";

  exit 0;
}

# auxiliary function to collect the subcommand
sub get_subcommand {
  my $ps_num_args = scalar @ARGV;

  if ($ps_num_args == 0) {
    _help('a');
  }
  else {
    # expect a subcommand or global option
    if ($ARGV[0] eq '-v' || $ARGV[0] eq '--version') {
      _version();
    }
    elsif ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
      _help('a');
    }
    elsif ($ARGV[0] eq $Status::TODO) {
      $DEFAULT_STATUS = $Status::TODO;
    }
    elsif ($ARGV[0] eq $Status::DONE) {
      $DEFAULT_STATUS = $Status::DONE;
    }
    elsif ($ARGV[0] eq $Status::WANT) {
      $DEFAULT_STATUS = $Status::WANT;
    }
    else {
      say "expected subcommand or global option";
      exit 1;
    }

    shift @ARGV;
  }

  if ($ps_num_args == 1) {
    $ACTION = $Action::SHOW;
  }
}

# process non-option arguments into a list of keys and values
sub get_args {
  my @pa_out  = ();

  my $pa_key   = "";
  my $pa_blob  = [];
  my $pa_count = 0;
  foreach (@ARGV) {
    # arg is form 'key.'
    # finish with current hash, if any, and initialize a new one
    if (m/^\s*(.+?)\.\s*$/) {
      push @pa_out, [$pa_key, $pa_blob] if $pa_count;

      $pa_key   = $1;
      $pa_blob  = [];
      $pa_count = 0;

      next;
    }

    # arg is form 'key.val'
    # reset $key and add current hash unless empty and add a pair
    if (m/^\s*(.+?)\.(.+)\s*$/) {
      if ($pa_key ne $1) {
        push @pa_out, [$pa_key, $pa_blob] if $pa_count;
      }
      
      $pa_key   = "";
      $pa_blob  = [];
      $pa_count = 0;

      push @pa_out, [$1, [$2] ];

      next;
    }

    # arg is form 'val'
    # if $key is "", push to list; else add to current blob 
    if (m/^\s*([^\.]+)\s*$/) {
      if ($pa_key eq "") {
        push @pa_out, $1;
      }
      else {
        $pa_count++;

        push @$pa_blob, $1;
      }

      next;
    }

    say "arg $_ is invalid";
    exit 1;
  }

  if ($pa_count) {
    push @pa_out, [$pa_key, $pa_blob];
  }

  return @pa_out;
}

# load the global configuration file settings
sub configure_app {
  return 1;
}

# search recursively upward from the current directory for todos
# until any project or the home directory is found
sub find_project {
  my $fp_dir = cwd;
  my $fp_file = $fp_dir . '/' . '.todos';

  if ($fp_dir !~ /^$ENV{HOME}/) {
    $fp_dir = $ENV{HOME};
  }
  elsif ($fp_dir ne $ENV{HOME}) {
    until ($fp_dir eq $ENV{HOME}) {
      last if -f $fp_file;

      $fp_dir  = dirname $fp_dir;
      $fp_file = $fp_dir . '/' . '.todos';
    }
  }
  
  unless (-f $fp_file) {
    say "no project file found";
    exit 1;
  }

  return $fp_file;
}

# does list item have a status?
sub _has_the_status {
  my ($item, $status) = @_;

  if (ref($item) eq "HASH") {
    if (exists $item->{status}) {
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
sub _has_key {
  my ($project, $key) = @_;

  return (exists $project->{contents}{$key});
}

# is scalar a todo list?
sub _has_contents {
  my $val = shift;

  return (ref($val) eq 'HASH' && exists $val->{contents}
    && ref($val->{contents}) eq 'HASH');
}

# create an item or maybe change an existing one
sub create_stuff {
  my ($cs_file, $cs_project, $cs_args) = @_;

  my $cs_item = _cs_maker();
  for (@$cs_args) {
    if ($MOVE_ENABLED
      && _apply_to_matches(\&_cs_mover, $cs_project, $_)) {

      next;
    }
    elsif (ref($_) eq 'ARRAY') {
      say "adding contents of array"; #ASSERT
      my $cs_sublist = $cs_project->{contents}{ $_->[0] };

      # make several items with identical values in a sublist
      for my $cs_item_name (@{ $_->[1] }) {
        $cs_sublist->{contents}{$cs_item_name} = $cs_item;
      }
    }
    else {
      say "adding a simple scalar"; #ASSERT
      # make one item using $STATUS, $PRIORITY, $DESCRIPTION
      $cs_project->{contents}{$_} = $cs_item;
    }
  }

  DumpFile($cs_file, $cs_project);

  return 0;
}

# passed to _apply_to_matches by create_stuff to move an item
sub _cs_mover {
  my ($project, $key) = @_;

  if (ref() eq 'HASH') {
    $project->{contents}{$key}{status} = $DEFAULT_STATUS;
  }
  else {
    $project->{contents}{$key} = $DEFAULT_STATUS;
  }
}

sub _cs_maker {
  my $out = {};

  if ($PRIORITY eq '' && $DESCRIPTION eq '') {
    if ($STATUS eq '') {
      return $DEFAULT_STATUS;
    }
    else {
      return $STATUS;
    }
  }
  elsif ($PRIORITY eq '') {
    $out->{description} = $DESCRIPTION unless ($DESCRIPTION eq '');
  }
  elsif ($DESCRIPTION eq '') {
    $out->{priority} = $PRIORITY unless ($PRIORITY eq '');
  }
  else {
    $out->{status} = $STATUS unless ($STATUS eq '');
  }
  
  return $out;
}

# call a function on all relevant items
sub _apply_to_matches {
  my $sub   = shift;
  my $start = shift;
  my $key   = shift;

  if (ref($key) eq 'ARRAY') {
    return 0 unless _has_key($start, $key->[0]);

    my $count   = 0;
    my $sublist = $start->{contents}{ $key->[0] };

    if (_has_contents($sublist)) {
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
    return 0 unless _has_key($start, $key);

    &{ $sub }($start, $key);
  }

  return 1;
}

# change relevant items 
sub edit_stuff {
  my ($es_file, $es_project, $es_args) = @_;
  
  unless (_has_contents($es_project)) {
    say "value of contents in list or sublist MUST be hash";
    return 1;
  }

  foreach (@$es_args) {
    _apply_to_matches(\&_es_set_attrs, $es_project, $_);
  }

  DumpFile($es_file, $es_project);

  return 0;
}

# passed to _apply_to_matches by edit_stuff to change items
sub _es_set_attrs {
  say "setting attrs ..."; #ASSERT
  my ($list, $key) = @_;

  my $contents = $list->{contents};

  return if ($STATUS eq '' && $PRIORITY eq '' && $DESCRIPTION eq '');

  my $replacement = {};

  if (ref($contents->{$key}) eq "HASH") {
    $replacement = $contents->{$key};
  }
  
  unless ($STATUS eq '') {
    $replacement->{status} = $STATUS;
  }

  unless ($PRIORITY eq '') {
    $replacement->{priority} = $PRIORITY;
  }

  unless ($DESCRIPTION eq '') {
    $replacement->{description} = $DESCRIPTION;
  }

  $contents->{$key} = $replacement;
}

# print information about items in list
sub show_stuff {
  my ($ss_project, $ss_args) = @_;

  unless (_has_contents($ss_project)) {
    say "error: nothing to show";

    return 1;
  }

  if (scalar @$ss_args) {
    foreach (@$ss_args) {
      # ignore arrayref args
      if (ref($_) eq '') {
        _apply_to_matches(\&_ss_dumper, $ss_project, $_);
      }
    }
  }
  else {
    _ss_dumper($ss_project, '');
  }

  return 0;
}

# print contents of 'list' if items have the right status
sub _ss_dumper {
  my $project = shift;
  my $key     = shift;

  my $has_printed_key = 0;
  $has_printed_key    = 1 if $key eq '';

  if ($key eq '') {
    # print each item, excluding sublists, if it has the right status
    # apply the same rule to the ITEMS of a sublist
    while ((my ($k, $v) = each %{ $project->{contents} })) {
      if (_has_contents($v)) {
        _ss_dumper($project, $k);
      }
      elsif (_has_the_status($v, $DEFAULT_STATUS)) {
        say $k; # TODO show more information about todo, i.e. attributes
      }
    }
  }
  else { 
    my $sublist = $project->{contents}{$key};

    return unless _has_contents($sublist);

    while ((my ($k, $v) = each %{ $sublist->{contents} })) {
      if (_has_the_status($v, $DEFAULT_STATUS)) {
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
sub delete_stuff {
  my ($ds_file, $ds_data, $ds_args) = @_;

  unless (_has_contents($ds_data)) {
    say "nothing to delete";
    return 1;
  }

  my $ds_contents = $ds_data->{contents};
  if (scalar @$ds_args) {
    foreach (@$ds_args) {
      _apply_to_matches(\&_ds_deleter, $ds_data, $_);
    }
  }
  else {
    for my $key (keys %{$ds_contents}) {
      if (_has_the_status($ds_contents->{$key}, $DEFAULT_STATUS)) {
        delete $ds_contents->{$key};
      }
      elsif (_has_contents($ds_contents->{$key})) {
        while ((my ($subkey, $subvalue) = each %{ $ds_contents->{$key}{contents} })) {
          _ds_deleter($ds_contents->{$key}, $subkey);
        }
      }
    }
  }

  DumpFile($ds_file, $ds_data);

  return 0;
}

# passed to _apply_to_matches by delete_stuff to remove an item
sub _ds_deleter {
  my ($project, $key) = @_;

  if (_has_the_status($project->{contents}{$key}, $DEFAULT_STATUS)) {
    delete $project->{contents}{ $key };
  }
}

__END__

=head1 Name

todo -- manage your todo list

  todo [global options] [subcommand] [options] [arguments]

=head1 Summary

C<todo> helps you manage your todo list. Your list is a YAML file, which
does not really contain a list, but a hash table. Your list is composed
of items. An item has a name, which is the key to the hash table, and at
least one attribute, its status. See the example below.

  ---
  name: today
  contents:
    wake: did
    eat: want
    sleep: do
    code:
      status: do
  ...

The above yaml snippet shows two ways to set the status: as the value of
the item in the document's B<contents> hash; and as the value of the
key below the item. Either approach is valid. Note that in any case,
every item B<must> be assigned a status. Status is a way of describing
the current condition of an item. By default, you may choose from three
statuses: "do", "did", and "want". Incidentally, the "subcommand" you
use corresponds to the status of the items you want to create, see,
delete, or edit.

The status is one of three possible attributes that an item may have.
Unlike the status attribute, these attributes need not be present in an item.
The other two attributes are priority, a positive integer, and description.
A priority of zero is the default and is the 'first' priority, much as
zero is the first index of arrays in most programming languages. The
description is simply a string which should be used to clarify the
meaning of an item.

Items may contain an additional member: contents. The presence of this
key indicates that an item is a todo list in its own right. Such a
sublist may contain items just like its parent, with one exception:
further sublists. 

  ---
  name: tomorrow
  contents:
    wake: do
    eat: want
    other:
      status: do
      contents:
        walk my dog: do
        sacrifice to Odin: do
  ...

Notice that both the parent todo list and its sublist other have a
I<contents> key. The contents key is required for a list to be
recognized.

=head1 Subcommands

Before you ask, the subcommands are not in fact "commands"; the actual
commands reside among the regular options. You may attribute this mangling
of convention to two lines of reasoning: first, I believed that the order
of command-line arguments should correspond to how I formulate a todo in
my own mind. I think first that I should B<do> foo, not B<add> foo to
the list of items that I must do. Secondly, I found that using status
instead of true commands better facilitated my two most common use
cases: looking at everything in a list with a particular status, and
adding a new item somewhere. For comparison, 

  todo do     # shows everything with "do" status
  todo do foo # adds a new item called foo with "do" status

allows me to differentiate between showing and adding items simply by
the presence or absence of additional arguments. But

  todo show --do
  todo add --do foo

requires an extra piece of information in most cases (if "do" were the
default status we could shorten this example by removing C<--do>,
but this still leaves the other statuses. Judge this tradeoff how you
will.

=over 4

=item do

select items with "do" status

=item did

select items with "did" status

=item want

select items with "want" status

=back

=head1 General Options

=over 4

=item -h|--help

print help. if this option is supplied first, general help concerning
the options is printed. otherwise, it will print help for the current
subcommand

=item -v|--version

print application version information

=item -s|--show

print item/s from the currently selected list

=item -e|--edit

change list item information

=item -c|--create

add new item/s to selected list or move from another list

=item -C|--create-no-move

add new item/s to selected list without the possibility of moving
from another list

=item -d|--delete

remove item/s from selected list. 

=back

=head1 Arguments

arguments are used to identify items and groups of items. there are
three types of arguments:

=over 4

=item keys

Example: vim.

to be a key, an argument string must end on a '.'
a key starts a new sublist named after the key to which 
values will be added

=item values

Example: "read vim-perl help"

to be a value, an argument must simply not contain a '.'.
added to the list or a sublist, if one is active. add a description
to a value by following it with '='

=item key-value pairs

Examples: vim."read vim-perl help", vim.perl="read vim-perl help"

a key-value pair is a string with two parts separated by a '.'
adds to a sublist named after the key, creating the sublist if it does
not exist. add a description to a value by following it with '='

=back

=head1 Examples

todo do "eat something"

todo do "eat something" "walk the dog"

todo do exercise

todo do todo-app. "implement create" "implement delete" "implement show"

todo want -S

todo do -D todo-app."implement show"

=head1 Copyright and License

Copyright (C) 2018 Adam Marshall.
This software is distributed under the MIT License

=cut

