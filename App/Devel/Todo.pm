#! /usr/bin/env perl
#
# file: App/Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: definitions of todo utility functions

package App::Devel::Todo;

=pod

=cut

BEGIN {
  use Exporter;

  @ISA = qw/Exporter/;
  @EXPORT = qw/&run/;
}

use strict;
use warnings;

use feature qw/say/;

use Getopt::Long;
use Config::JSON;
use Pod::Usage;
use Cwd qw/cwd/;
use File::Basename;
use Carp;
use YAML::XS;

# actions the app may take upon the selected todos
package Action {
  use constant DELETE => 0; # remove a todo
  use constant CREATE => 1; # insert a todo
  use constant EDIT   => 2; # change the contents of a todo
  use constant SHOW   => 3; # print information about todo/s
}

# lists defined in a todos file
# the value of each constant is the key used to search for the
# corresponding list in the hash created on reading a todos file
package List {
  use constant TODO => "do";
  use constant DONE => "did";
  use constant WANT => "want";
}

our $VERSION      = 'v0.01';
our $cwd          = cwd;
our $config_file  = "$ENV{HOME}/.todorc"; # location of global configuration
our $todo_dir     = $cwd; # where the search for todo files begins
our $action       = Action::CREATE; # what will be done with the todos
our $move_source  = '';
our $move_enabled = 1;
our $focused_list = List::TODO; # which part of todo list will be accessed
our %opts = (
      'help|h'    => \&HELP,
      'version|v' => \&VERSION,
      'local|g'   => sub { $todo_dir = $cwd },
      'global|g'  => sub { $todo_dir = $ENV{HOME} },
      'delete|d'  => sub { $action   = Action::DELETE; },
      'create|c'  => sub { $action   = Action::CREATE; },
      'edit|e'    => sub { $action   = Action::EDIT; },
      'show|s'    => sub { $action   = Action::SHOW; },
      'W|move-from-want' => sub { $move_source = List::WANT; },
      'F|move-from-done' => sub { $move_source = List::DONE; },
      'D|move-from-todo' => sub { $move_source = List::TODO; },
      'n|no-move' => sub { $move_enabled = 0; }
    );

# print a help message appropriate to the situation and exit
sub HELP {
  my $help_type = shift || 's'; 
  my %messages = (
    List::TODO => "selects your todo list",
    List::DONE => "selects your list of finished tasks",
    List::WANT => "selects your list of goals",
    ALL        => "sinead helapth!"
  );
  
  if ($help_type eq 'a') {
    # general help
    say $messages{ALL};
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
    elsif ($args->[0] eq List::TODO) {
      $lst = List::TODO;
    }
    elsif ($args->[0] eq List::DONE) {
      $lst = List::DONE;
    }
    elsif ($args->[0] eq List::WANT) {
      $lst = List::WANT;
    }
    else {
      croak "expected subcommand or global option";
    }

    shift @$args;
  }

  if ($num_args == 1) {
    $act = Action::SHOW;
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

  # TODO doing nothing with this currently
  $json = Config::JSON->new($file) if -f $file;

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
  my $json_obj     = Config::JSON->new($project_file);
  my $data;
  my @args         = process_args(\@ARGV);

  # perform action on selected list
  if ($action == Action::CREATE) {
    # todo-list => check whether want contains item, moving if so
    if ($focused_list eq List::TODO) {
    
    }
    # done-list => check for item in todo, moving if so
    elsif ($focused_list eq List::DONE) {
    
    }
    # want-list => check for item in todo, moving if so
    elsif ($focused_list eq List::WANT) {
    
    }
  }
  elsif ($action == Action::SHOW) {
    $data = $json_obj->get($focused_list, "");

    # if arg given, iterate over list doing regex matches against each
    # simple scalar?
    # get keys of hash refs and iterate over them until match found

    print Dump $data if defined $data;
    say "";
  }
  elsif ($action == Action::DELETE) {
    # remove entirely from selected list
  }
  elsif ($action == Action::EDIT) {
    # edit an existing in the currently selected list
  }

  exit 0;
}
