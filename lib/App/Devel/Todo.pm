#! /usr/bin/env perl
# file: App/Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: define the command-line app's essential functions

package App::Devel::Todo;

use strict;
use warnings;

use feature qw/say/;

BEGIN {
  use Exporter;

  our @ISA = qw/Exporter/;
  our @EXPORT = qw/&Run/;
}

use File::Spec::Functions qw/catfile/;
use Getopt::Long qw/:config no_ignore_case/;
use Cwd qw/getcwd/;
use File::Basename qw/dirname/;
use YAML::XS qw/LoadFile/;

use Devel::Todo;

our $VERSION = '0.005002';

# print a help message appropriate to the situation and exit
sub help {
  my ($h_type, $h_custom_msg) = @_;

  my $h_general_msg = <<EOM;
Options:
-h|--help              print help
-v|--version           print application version information
-V|--verbose           print every item with its description
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

  if ($h_type eq 'a') {
    say $h_general_msg;
  }
  else {
    say $h_custom_msg;
  }

  exit 0;
}

# print the application name and version number and exit
sub version {
  say "todo $VERSION";

  exit 0;
}

# auxiliary function to collect the subcommand
sub get_possible_subcommand {
  my $gs_num_args = scalar @ARGV;
  my $gs_STATUS;

  if ($gs_num_args == 0) {
    help('a');
  }
  else {
    if ($ARGV[0] eq '-v' || $ARGV[0] eq '--version') {
      version();
    }
    elsif ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
      help('a');
    }
    elsif ($ARGV[0] =~ m/\w[\w\-\+\.\/]*/) {
      # first arg to program looks like a "word", so it may
      # be a valid subcommand/status
      $gs_STATUS = $ARGV[0];
    }
    else {
      return ('', 0);
    }

    shift @ARGV;
  }

  return ($gs_STATUS, 1);
}

# process non-option arguments after the subcommand into
# a list of keys and values
sub process_args {
  my @pa_out  = ();

  # the following variables matter ONLY in the case that
  # some args target items in a sublist
  my $pa_sublist_key   = ""; # name of focused sublist
  my $pa_sublist_blob  = []; # list of items in focused sublist
  my $pa_sublist_count = 0;  # number of sublist elements in blob
  foreach (@ARGV) {
    # arg is form 'key.'
    # finish with current blob, if any, and initialize a new one
    if (m/^\s*(.+?)\.\s*$/) {
      if ($pa_sublist_count > 0) {
        push @pa_out, [$pa_sublist_key, $pa_sublist_blob];
      }

      $pa_sublist_key   = $1;
      $pa_sublist_blob  = [];
      $pa_sublist_count = 0;

      next;
    }

    # arg is form 'key.val'
    # reset $key and add current blob unless empty
    if (m/^\s*(.+?)\.(.+)\s*$/) {
      if ($pa_sublist_key ne $1) {
        if ($pa_sublist_count > 0) {
          push @pa_out, [$pa_sublist_key, $pa_sublist_blob];
        }
      }
      
      $pa_sublist_key   = "";
      $pa_sublist_blob  = [];
      $pa_sublist_count = 0;

      push @pa_out, [$1, [$2] ];

      next;
    }

    # arg is form 'val'
    # if $key is "", push blob; else add to current blob 
    if (m/^\s*([^\.]+)\s*$/) {
      if ($pa_sublist_key eq "") {
        push @pa_out, $1;
      }
      else {
        $pa_sublist_count++;

        push @$pa_sublist_blob, $1;
      }

      next;
    }

    return ([], 0);
  }

  if ($pa_sublist_count) {
    push @pa_out, [$pa_sublist_key, $pa_sublist_blob];
  }

  return (\@pa_out, 1);
}

# load the global configuration file settings
# TODO setting default values
sub configure_app {
  my ($ca_file, $ca_statuses) = @_;

  my $ca_settings = LoadFile($ca_file);
  
  # create new statuses, if any
  if (defined $ca_settings->{statuses}) {
    foreach (keys %{ $ca_settings->{statuses} }) {
      if ($_ =~ m/\w[\w\-\+\.\/]*/ && !exists($ca_statuses->{$_})) {
        if (ref $ca_settings->{statuses}{$_} eq '') {
          $ca_statuses->{$_} = $ca_settings->{statuses}{$_};
        }
        else {
          return (0, "new status $_ is missing help message");
        }
      }
      else {
        return (0, "new status $_ already exists or is invalid");
      }
    }
  }

  # set defaults, if any
  return (1, '');
}

# search recursively upward from the current directory for todos
# until any project or the home directory is found
sub find_project_file {
  my $fp_dir  = getcwd;
  my $fp_file = catfile($fp_dir, '.todos');

  # we can find a project only in the user's home directory
  # or descendants of it
  if ($fp_dir !~ /^$ENV{HOME}/) {
    $fp_dir = $ENV{HOME};
  }
  elsif ($fp_dir ne $ENV{HOME}) {
    until ($fp_dir eq $ENV{HOME}) {
      last if -f $fp_file;

      $fp_dir  = dirname $fp_dir;
      $fp_file = catfile($fp_dir, '.todos');
    }
  }
  
  return $fp_file;
}

# main application logic
sub Run {
  my $r_config_file = catfile($ENV{HOME}, '.todorc.yml');

  # define possible actions
  my $r_create = 0;
  my $r_show   = 1;
  my $r_edit   = 2;
  my $r_delete = 3;

  # the general action which will be taken by the program
  my $r_action = $r_create;

  # controls whether a help message will be printed for subcommand
  my $r_help_requested = 0;

  # set to 1 when an option explicitly gives the action to use:
  # -C, -S, -N, -D, -E
  my $r_action_requested = 0;

  # configuration passed to Devel::Todo->new
  my $r_dt_config = {
    STATUS              => 'do',
    MOVE_ENABLED        => 1,
    TODO_FILE           => '',
    STATUS_OPT          => '',
    PRIORITY_OPT        => '',
    DESCRIPTION_OPT     => '',
    DEFAULT_STATUS      => 'do',
    DEFAULT_PRIORITY    => 0,
    DEFAULT_DESCRIPTION => '',
    VERBOSE             => 0,
  };

  # defines default statuses. new statuses in config file will
  # be added here
  my %r_statuses = (
    all  => 'selects every item regardless of status',
    do   => 'selects list of todos',
    did  => 'selects list of finished items',
    want => 'selects list of goals'
  );

  # declare command-line options
  my %r_opts = (
    'help|h'           => sub { $r_help_requested = 1; },
    'version|v'        => \&version,
    'verbose|V'        => sub { $r_dt_config->{VERBOSE} = 1; },
    'delete|D'         => sub { $r_action = $r_delete; $r_action_requested = 1; },
    'create|C'         => sub { $r_action = $r_create; $r_action_requested = 1; },
    'edit|E'           => sub { $r_action = $r_edit; $r_action_requested = 1; },
    'show|S'           => sub { $r_action = $r_show; $r_action_requested = 1; },
    'create-no-move|N' => sub { 
                                $r_action = $r_create;
                                $r_dt_config->{MOVE_ENABLED} = 0;
                                $r_action_requested = 1;
                              },
    'config-file|f=s'     => \$r_config_file,
    'todo-file|t=s'       => \$r_dt_config->{TODO_FILE},
    'use-status|s=s'      => \$r_dt_config->{STATUS_OPT},
    'use-priority|p=s'    => \$r_dt_config->{PRIORITY_OPT},
    'use-description|d=s' => \$r_dt_config->{DESCRIPTION_OPT}
  );

  # the possible subcommand retrieved here will be verified
  # after the config file has been processed, since new statuses/
  # subcommands may be defined there
  my ($r_status, $r_ok) = get_possible_subcommand();
  unless ($r_ok) {
    die "error: expected global option or subcommand";
  }

  unless (GetOptions(%r_opts)) {
    exit 1;
  }

  # set the action to use implicitly based on number of args
  # after subcommand and options have been extracted
  if ($r_action_requested == 0) {
    # if there are any args, attempt to create them in the todo list
    if (@ARGV) {
      $r_action = $r_create;
    }
    # otherwise, show the entire todo list
    else {
      $r_action = $r_show;
    }
  }

  # reads the configuration file, sets new app defaults if any
  # defined, and creates new subcommands/statuses. if any of the
  # latter are invalid for some reason, they will be ignored
  my $r_error;
  ($r_ok, $r_error) = configure_app($r_config_file);
  die $r_error unless $r_ok;

  # verify the possible subcommand
  if (exists $r_statuses{$r_status}) {
    $r_dt_config->{STATUS} = $r_status;
  }
  else {
    die("error: unknown subcommand: $r_status");
  }

  # because the default status is used extensively to search within
  # and modify the todos, the default status may not have a value of
  # 'all'. this is to prevent confusion between what is a status
  # value (e.g. 'do', 'did') and what is a status representative
  # (e.g. 'all'). no list item may have a status of 'all' because
  # it is not a status value
  unless ($r_dt_config->{STATUS} eq 'all') {
    $r_dt_config->{DEFAULT_STATUS} = $r_dt_config->{STATUS};
  }
  
  # prints help for subcommand
  # this function is called here because not all subcommands
  # may be known until after the app is configured
  help('s', $r_statuses{ $r_dt_config->{STATUS} }) if $r_help_requested;

  # processes remaining command-line arguments into keys and values
  # so that it is clear which parts of the todos will be affected
  my $r_args;
  ($r_args, $r_ok) = process_args();
  unless ($r_ok) {
    die "error: invalid args to program";
  }

  my $r_project_file = find_project_file();
  unless (-f $r_project_file) {
    die "error: unable to find project file";
  }

  my $r_todo = Devel::Todo->new($r_project_file, $r_dt_config);

  if ($r_action == $r_create) {
    $r_todo->Add_Element($r_args);
  }
  elsif ($r_action == $r_show) {
    $r_todo->Show_Element($r_args);
  }
  elsif ($r_action == $r_edit) {
    $r_todo->Edit_Element($r_args);
  }
  elsif ($r_action == $r_delete) {
    $r_todo->Delete_Element($r_args);
  }
}

__END__

=head1 Name

todo -- manage your todo list

  todo [global options] [subcommand] [options] [arguments]

=head1 Summary

C<todo> helps you manage your todo list. your list is a YAML file, which
does not really contain a list, but a hash table. your list is composed
of items. an item has a name, which is the key to the hash table, and at
least one attribute, its status. see the example below.

  ---
  name: today
  contents:
    wake: did
    eat: want
    sleep: do
    code:
      status: do
  ...

the above yaml snippet shows two ways to set the status: as the value of
the item in the document's B<contents> hash; and as the value of the
key below the item. either approach is valid. note that in any case,
every item B<must> be assigned a status. status is a way of describing
the current condition of an item. by default, you may choose from three
statuses: "do", "did", and "want". incidentally, the "subcommand" you
use corresponds to the status of the items you want to create, see,
delete, or edit.

the status is one of three possible attributes that an item may have.
unlike the status attribute, these attributes need not be present in an item.
the other two attributes are priority, a positive integer, and description.
a priority of zero is the default and is the 'first' priority, much as
zero is the first index of arrays in most programming languages. the
description is simply a string which should be used to clarify the
meaning of an item.

items may contain an additional member: contents. the presence of this
key indicates that an item is a todo list in its own right. such a
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

notice that both the parent todo list and its sublist 'other' have a
I<contents> key. the contents key is required for a list to be
recognized.

=head1 Subcommands

before you ask, the subcommands are not in fact "commands"; the actual
commands reside among the regular options. you may attribute this mangling
of convention to three lines of reasoning: first, I believed that the order
of command-line arguments should correspond to how I formulate a todo in
my own mind. I think first that I should B<do> foo, not B<add> foo to
the list of items that I must do. secondly, I found that using status
instead of true commands better facilitated my two most common use
cases: looking at everything in a list with a particular status, and
adding a new item somewhere. for comparison, 

  todo do     # shows everything with "do" status
  todo do foo # adds a new item called foo with "do" status

allows me to differentiate between showing and adding items simply by
the presence or absence of additional arguments. but

  todo show --do
  todo add --do foo

requires an extra piece of information in most cases (if "do" were the
default status we could shorten this example by removing C<--do>,
but this still leaves the other statuses. finally, I wanted to allow
users to define new statuses particular to how they work, which would
be easier to support if the status had to appear as the first argument
to C<todo>.

NOTE: except for 'all', the subcommand sets the default status used by the
program

the following subcommands are automatically defined:

=over 4

=item do

select items with "do" status

=item did

select items with "did" status

=item want

select items with "want" status

=item all

select everything, regardless of status. this subcommand cannot be
used in combination with creating or editing items

=back

=head1 General Options

=over 4

=item -h|--help

print help. if this option is supplied first, general help concerning
the options is printed. otherwise, it will print help for the current
subcommand

=item -v|--version

print application version information

=item -V|--verbose

print every item with its description

=item -S|--show

print item/s from the currently selected list

=item -E|--edit

change list item information

=item -C|--create

add new item/s to selected list or move from another list

=item -N|--create-no-move

add new item/s to selected list without the possibility of moving
from another list

=item -D|--delete

remove item/s from selected list. 

=item -s|--use-status

specify a status. this is relevant when creating or editing items,
and it is different from the status set by the subcommand

=item -d|--use-description

specify a description. this is relevant when creating or editing items

=item -p|--use-priority

specify a priority. this is relevant when creating or editing items

=item -f|--config-file

specify a different file to use as configuration file

=item -t|--todo-file

specify a different file to use as project todo list

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

examples: vim."read vim-perl help", vim.perl="read vim-perl help"

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

