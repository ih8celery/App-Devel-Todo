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
  our @EXPORT = qw/&run/;
  our %EXPORT_TAGS = (
    test => [qw/&run &configure_app &find_project/]
  );
}

use feature qw/say/;

use Const::Fast;
use Getopt::Long;
use Cwd qw/cwd/;
use File::Basename;
use Carp;
use YAML::XS qw/LoadFile Dump/;

# actions the app may take upon the selected todos
package Action {
  use Const::Fast;

  const our $DELETE => 0; # remove a todo
  const our $CREATE => 1; # insert a todo
  const our $EDIT   => 2; # change the contents of a todo
  const our $SHOW   => 3; # print information about todo/s
}

# lists defined in a todos file
package List {
  use Const::Fast;

  const our $TODO => "do";
  const our $DONE => "did";
  const our $WANT => "want";
}

our $VERSION      = '0.01';
our $CWD          = cwd;
our $CONFIG_FILE  = "$ENV{HOME}/.todorc"; # location of global configuration
our $TODO_DIR     = $CWD; # where the search for todo files begins
our $ACTION       = $Action::CREATE; # what will be done with the todos
our $MOVE_SOURCE  = '';
our $MOVE_ENABLED = 1;
our $FOCUSED_LIST = $List::TODO; # which part of todo list will be accessed
our %OPTS = (
      'help|h'    => \&HELP,
      'version|v' => \&VERSION,
      'local|g'   => sub { $TODO_DIR = $CWD },
      'global|g'  => sub { $TODO_DIR = $ENV{HOME} },
      'delete|d'  => sub { $ACTION   = $Action::DELETE; },
      'create|c'  => sub { $ACTION   = $Action::CREATE; },
      'edit|e'    => sub { $ACTION   = $Action::EDIT; },
      'show|s'    => sub { $ACTION   = $Action::SHOW; },
      'W|move-from-want' => sub { $MOVE_SOURCE = $List::WANT; },
      'F|move-from-done' => sub { $MOVE_SOURCE = $List::DONE; },
      'D|move-from-todo' => sub { $MOVE_SOURCE = $List::TODO; },
      'C|create-no-move' => sub { $ACTION = $Action::CREATE; $MOVE_ENABLED = 0; }
);

# print a help message appropriate to the situation and exit
sub HELP {
  my $h_type = shift || 's';
  my $h_general_help = <<EOM;
-h|--help            print help
-v|--version         print application version information
-s|--show            print item/s from the currently selected list
-e|--edit            change list item information
-c|--create          add new item/s to selected list or move from another list
-C|--create-no-move  add new item/s to selected list without moving
-d|--delete          remove item/s from selected list. 
-l|--local           attempt to find ".todos" in the current working directory
-g|--global          search \$HOME for ".todos"
-W|--move-from-want  if moving would occur, use the "want" list
-F|--move-from-done  if moving would occur, use the "done" list
-D|--move-from-todo  if moving would occur, use the "todo" list
EOM

  my %h_messages = (
    $List::TODO => "selects your todo list",
    $List::DONE => "selects your list of finished tasks",
    $List::WANT => "selects your list of goals"
  );
  
  if ($h_type eq 'a') {
    # general help
    say $h_general_help;
  }
  else {
    # help with subcommand
    say $h_messages{$FOCUSED_LIST};
  }

  exit 0;
}

# print the application name and version number and exit
sub VERSION {
  say "todo $VERSION";

  exit 0;
}

# auxiliary function to collect the subcommand
sub process_subcommand {
  my $ps_num_args = scalar @ARGV;

  if ($ps_num_args == 0) {
    HELP('a');
  }
  else {
    # expect a subcommand or global option
    if ($ARGV[0] eq '-v' || $ARGV[0] eq '--version') {
      VERSION();
    }
    elsif ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
      HELP('a');
    }
    elsif ($ARGV[0] eq $List::TODO) {
      $FOCUSED_LIST = $List::TODO;
    }
    elsif ($ARGV[0] eq $List::DONE) {
      $FOCUSED_LIST = $List::DONE;
    }
    elsif ($ARGV[0] eq $List::WANT) {
      $FOCUSED_LIST = $List::WANT;
    }
    else {
      croak "expected subcommand or global option";
    }

    shift @ARGV;
  }

  if ($ps_num_args == 1) {
    $ACTION = $Action::SHOW;
  }
}

# process non-option arguments into a list of keys and values
sub process_args {
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

      push @pa_out, [$1, $2];

      next;
    }

    # arg is form 'val'
    # if $key is "", push to list; else add to current blob 
    if (m/^\s*([^\.]+)\s*$/) {
      if ($pa_key eq "") {
        push @pa_out, $1;
      }
      else {
        push @$pa_blob, $1;
      }

      next;
    }

    croak "arg $_ is invalid";
  }

  if ($pa_count) {
    push @pa_out, [$pa_key, $pa_blob];
  }

  return @pa_out;
}

# return the name of the list which should be used for moving
sub get_move_source {
  return $MOVE_SOURCE if ($MOVE_SOURCE ne '');

  return $List::WANT if ($FOCUSED_LIST eq $List::TODO);

  return $List::TODO if ($FOCUSED_LIST eq $List::WANT);

  return $List::TODO if ($FOCUSED_LIST eq $List::DONE);
}

# load the global configuration file settings
sub configure_app {
  return 1;
}

# search recursively upward from the current directory for todos
# until any project or the home directory is found
sub find_project {
  my $fp_dir;
  if (-d $TODO_DIR) {
    $fp_dir = $TODO_DIR;
  }
  else {
    $fp_dir = $ENV{HOME};
  }

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
  
  croak "no project file found" unless -f $fp_file;

  return $fp_file;
}

sub create_stuff {
  my ($file, $contents, $args) = @_;

  return 0;
}

sub edit_stuff {
  my ($file, $contents, $args) = @_;

  return 0;
}

sub show_stuff {
  my ($ss_project, $ss_args) = @_;

  unless (exists $ss_project->{contents}
      and ref($ss_project->{contents}) eq "HASH") {

    say "error: nothing to show";

    return 1;
  }

  # try to print args that name sublists
  if (scalar @$ss_args) {
    my $ss_contents = $ss_project->{contents};

    foreach (@$ss_args) {
      if (ref($_) eq '') {
        if (exists $ss_contents->{ $_ } && ref($ss_contents->{ $_ }) eq "HASH") {
          ss_dump_stuff($ss_contents->{ $_ }, $_, 0);
        }
      }
    }
  }
  # just print everything that is not too deeply nested
  else {
    ss_dump_stuff($ss_project, "", 0);
  }

  return 0;
}

# print contents of 'list' if have the right status
sub ss_dump_stuff {
  my $stuff = shift;
  my $head  = shift;
  my $shift = shift || 0;

  my $has_printed_head = 0;

  $has_printed_head = 1 if ($head eq "");

  return if ($shift > 1);

  while ((my ($key, $value) = each %{ $stuff->{contents} })) {
    my $reftype = ref $value;

    if ($reftype eq "") {
      if ($value eq $FOCUSED_LIST) {
        unless ($has_printed_head) {
          say ' ' x ($shift - 1), $head, ':';
          $has_printed_head = 1;
        }

        say ' ' x $shift, $key;
      }
    }
    elsif ($reftype eq "HASH" and exists $value->{contents}) {
      ss_dump_stuff($value, $key, $shift + 1);
    }
    elsif ($reftype eq "HASH") {
      if (exists $value->{status}) {
        if ($value->{status} eq $FOCUSED_LIST) {
          unless ($has_printed_head) {
            say ' ' x ($shift - 1), $head, ':';
            $has_printed_head = 1;
          }

          say ' ' x $shift, $key;
        }
      }
      else {
        if ($FOCUSED_LIST eq $List::TODO) {
          unless ($has_printed_head) {
            say ' ' x ($shift - 1), $head, ':';
            $has_printed_head = 1;
          }

          say $key;
        }
      }
    }
  }
}

sub delete_stuff {
  my ($file, $contents, $args) = @_;

  return 0;
}

# main application logic
sub run {
  configure_app($CONFIG_FILE);
  
  process_subcommand();

  if (! GetOptions(%OPTS)) {
    exit 1;
  }

  if ($MOVE_SOURCE eq '') {
    if ($FOCUSED_LIST eq $List::WANT) {
      $MOVE_SOURCE = $List::TODO;
    }
    elsif ($FOCUSED_LIST eq $List::TODO) {
      $MOVE_SOURCE = $List::WANT;
    }
    else {
      $MOVE_SOURCE = $List::TODO;
    }
  }

  my @r_args = process_args();

  my $r_project_file = find_project();

  my $r_todos = LoadFile($r_project_file);

  if ($ACTION == $Action::CREATE) {
    exit create_stuff($r_project_file, $r_todos, \@r_args);
  }
  elsif ($ACTION == $Action::SHOW) {
    exit show_stuff($r_todos, \@r_args);
  }
  elsif ($ACTION == $Action::EDIT) {
    exit edit_stuff($r_project_file, $r_todos, \@r_args);
  }
  elsif ($ACTION == $Action::DELETE) {
    exit delete_stuff($r_project_file, $r_todos, \@r_args);
  }
}

__END__

=head1 Summary

C<todo> helps you manage your todo list by reading and writing to a
YAML file. the file contains three lists for simplicity: the list of
things to do, the list of things already done, and the list of things
you may want to do but cannot prioritize now

=head1 Usage

todo [subcommand] [options] [arguments]

=head2 Subcommands

there are three subcommands which identify the list upon which the
app will act:

=over 4

=item do

select the list of todos

=item did

select the list of completed items

=item want

select the list of goal items

=back

=head2 General Options

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

=item -l|--local

attempt to find ".todos" in the current working directory. ignored
if directory is not descended from $HOME. creates a file if no
".todos" exists in directory

=item -g|--global

search $HOME for ".todos". if the file is not found, it will be
created

=item -W|--move-from-want

if moving would occur, use the "want" list instead of the default

=item -F|--move-from-done

if moving would occur, use the "done" list instead of the default

=item -D|--move-from-todo

if moving would occur, use the "todo" list instead of the default

=back

=head2 Arguments

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

Sample ".todos":

---
todo:
  - finish documenting todo-app
did:
  - wash dirty laundry
want:
  - exercise
  - sleep
...


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

