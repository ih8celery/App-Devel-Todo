#! /usr/bin/env perl
#
# file: App/Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: definitions of todo utility functions

package App::Devel::Todo;

use strict;
use warnings;

BEGIN {
  use Exporter;

  @ISA = qw/Exporter/;
  @EXPORT = qw/&run/;
}

use feature qw/say/;

use Const::Fast;
use Getopt::Long;
use Cwd qw/cwd/;
use File::Basename;
use Carp;
use YAML::XS;

# actions the app may take upon the selected todos
package Action {
  const our $DELETE => 0; # remove a todo
  const our $CREATE => 1; # insert a todo
  const our $EDIT   => 2; # change the contents of a todo
  const our $SHOW   => 3; # print information about todo/s
}

# lists defined in a todos file
# the value of each constant is the key used to search for the
# corresponding list in the hash created on reading a todos file
package List {
  const our $TODO => "do";
  const our $DONE => "did";
  const our $WANT => "want";
}

our $VERSION      = '0.01';
our $cwd          = cwd;
our $config_file  = "$ENV{HOME}/.todorc"; # location of global configuration
our $todo_dir     = $cwd; # where the search for todo files begins
our $action       = $Action::CREATE; # what will be done with the todos
our $move_source  = '';
our $move_enabled = 1;
our $focused_list = $List::TODO; # which part of todo list will be accessed
our %opts = (
      'help|h'    => \&HELP,
      'version|v' => \&VERSION,
      'local|g'   => sub { $todo_dir = $cwd },
      'global|g'  => sub { $todo_dir = $ENV{HOME} },
      'delete|d'  => sub { $action   = $Action::DELETE; },
      'create|c'  => sub { $action   = $Action::CREATE; },
      'edit|e'    => sub { $action   = $Action::EDIT; },
      'show|s'    => sub { $action   = $Action::SHOW; },
      'W|move-from-want' => sub { $move_source = $List::WANT; },
      'F|move-from-done' => sub { $move_source = $List::DONE; },
      'D|move-from-todo' => sub { $move_source = $List::TODO; },
      'C|create-no-move' => sub { $move_enabled = 0; }
    );

# print a help message appropriate to the situation and exit
sub HELP {
  my $help_type = shift || 's';
  my $general_help = <<EOM;
-h|--help    print help
-v|--version print application version information
-s|--show    print item/s from the currently selected list
-e|--edit    change list item information
-c|--create  add new item/s to selected list or move from another list
-C|--create-no-move add new item/s to selected list without moving
-d|--delete  remove item/s from selected list. 
-l|--local   attempt to find ".todos" in the current working directory
-g|--global  search \$HOME for ".todos"
-W|--move-from-want  if moving would occur, use the "want" list
-F|--move-from-done  if moving would occur, use the "done" list
-D|--move-from-todo  if moving would occur, use the "todo" list
EOM

  my %messages = (
    $List::TODO => "selects your todo list",
    $List::DONE => "selects your list of finished tasks",
    $List::WANT => "selects your list of goals"
  );
  
  if ($help_type eq 'a') {
    # general help
    say $general_help;
  }
  else {
    # help with subcommand
    say $messages{$focused_list};
  }

  exit 0;
}

# print the application name and version number and exit
sub VERSION {
  say "todo $VERSION";

  exit 0;
}

# auxiliary function to collect the subcommand, if any
sub process_subcommand {
  my $args     = shift;
  my $num_args = @$args;
  my $lst      = $focused_list;
  my $act      = $action;

  if ($num_args == 0) {
    HELP('a');
  }
  else {
    # expect a subcommand or help or version request
    if ($args->[0] eq '-v' || $args->[0] eq '--version') {
      VERSION();
    }
    elsif ($args->[0] eq '-h' || $args->[0] eq '--help') {
      HELP('a');
    }
    elsif ($args->[0] eq $List::TODO) {
      $lst = $List::TODO;
    }
    elsif ($args->[0] eq $List::DONE) {
      $lst = $List::DONE;
    }
    elsif ($args->[0] eq $List::WANT) {
      $lst = $List::WANT;
    }
    else {
      croak "expected subcommand or global option";
    }

    shift @$args;
  }

  if ($num_args == 1) {
    $act = $Action::SHOW;
  }

  return ($lst, $act);
}

# process non-option arguments into a list of keys,
# together with any relevant data, ready to be used with a todo file
sub process_args {
  my $list = shift;
  my @out  = ();

  my @data;
  my $key        = "";
  my $hash_ref   = {};
  my $hash_count = 0;
  foreach (@$list) {
    # arg is form 'key.'
    # finish with current hash, if any, and initialize a new one
    if (m/^\s*(.+?)\.\s*$/) {
      push @out, { $key => $hash_ref } if $hash_count;

      # start fresh with new key
      $key        = $1;
      $hash_ref   = {};
      $hash_count = 0;

      next;
    }

    # arg is form 'key.val[=describe]'
    # reset $key and add current hash unless empty and add a pair
    if (m/^\s*(.+?)\.(.+)\s*$/) {
      if ($key ne $1) {
        push @out, { $key => $hash_ref } if $hash_count;
      }
      
      # start fresh
      $key        = "";
      $hash_ref   = {};
      $hash_count = 0;

      # get description, if any given
      @data = split '=', $2, 2;

      push @out, { $1 => { $data[0] => ($data[1] || "") } };

      next;
    }

    # arg is form 'val[=describe]'
    # if $key is "", push to list; else add to current hash 
    if (m/^\s*([^\.]+)\s*$/) {
      @data = split '=', $1, 2;
      
      if ($key eq "") {
        push @out, [ $data[0], ($data[1] || "") ];
      }
      else {
        if (!exists($hash_ref->{$data[0]})) {
          $hash_count++;
        }

        $hash_ref->{$data[0]} = ($data[1] || "");
      }

      next;
    }

    croak "arg $_ is invalid";
  }

  if ($hash_count) {
    push @out, { $key => $hash_ref };
  }

  return @out;
}

# run all configuration activities, including option parsing, 
# subcommand parsing, and reading the configuration file
sub configure_app {
  my $file = shift or croak "load_app_config: missing an argument";
  my $json;
  my %conf = ();

  ($focused_list, $action) = process_subcommand(\@ARGV);

  my $opt_success = GetOptions(%opts);

  if (! $opt_success) {
    exit 1;
  }

  return %conf;
}

# search recursively upward from the current directory for todos
# until any project or the home directory is found
sub find_project {
  my $dir;
  if (-d $todo_dir) {
    $dir = $todo_dir;
  }
  else {
    $dir = $ENV{HOME};
  }

  my $file = $dir . '/' . '.todos';

  if ($dir !~ /^$ENV{HOME}/) {
    $dir = $ENV{HOME};
  }
  elsif ($dir ne $ENV{HOME}) {
    until ($dir eq $ENV{HOME}) {
      last if -f $file;

      $dir  = dirname $dir;
      $file = $dir . '/' . '.todos';
    }
  }
  
  croak "no project file found" unless -f $file;

  return $file;
}

# contains main application logic
#
sub run {
  my %conf         = configure_app($config_file);
  my $project_file = find_project();
  my $todos        = Load($project_file);
  my $data;
  my @args         = process_args(\@ARGV);

  # perform action on selected list
  if ($action == $Action::CREATE) {
    # todo-list => check whether want contains item, moving if so
    if ($focused_list eq $List::TODO) {
    
    }
    # done-list => check for item in todo, moving if so
    elsif ($focused_list eq $List::DONE) {
    
    }
    # want-list => check for item in todo, moving if so
    elsif ($focused_list eq $List::WANT) {
    
    }
  }
  elsif ($action == $Action::SHOW) {
    $data = $todos->get($focused_list, "");

    # if arg given, iterate over list doing regex matches against each
    # simple scalar?
    # get keys of hash refs and iterate over them until match found

    print Dump $data if defined $data;
    say "";
  }
  elsif ($action == $Action::DELETE) {
    # remove entirely from selected list
  }
  elsif ($action == $Action::EDIT) {
    # edit an existing in the currently selected list
  }

  exit 0;
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

to be a key, an argument string must end on a '.'
a key starts a new sublist named after the key to which 
values will be added

=item values

to be a value, an argument must simply not contain a '.'.
added to the list or a sublist, if one is active

=item key-value pairs

a key-value pair is a string with two parts separated by a '.'
adds to a sublist named after the key, creating the sublist if it does
not exist

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

