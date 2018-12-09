#!/usr/bin/env perl

package Devel::CLI::CommandLineApp;

use Getopt::Long;

use Mouse;
with qw/Configurable Executable Describable/;

has "name"       => { is => "bare", isa => "Str" };
has "summary"    => { is => "bare", isa => "Str" };
has "topics"     => { is => "bare", isa => "HashRef" };
has "action"     => { is => "bare", isa => "CodeRef" };
has "properties" => { is => "bare", isa => "HashRef" };

sub name {
  my ($self, $name) = @_;

  if (defined $name) {
    $self->{name} = $name;
  }
  else return $self->{name};
}

sub summary {
  my ($self, $summary) = @_;

  if (defined $summary) {
    $self->{summary} = $summary;
  }
  else return $self->{summary};
}

sub info {
  my ($self, $topicname, $summary) = @_;

  if (defined $topicname && defined $summary) {
    $self->{topics}{ $topicname } = $summary;
  }
  elsif (defined $topicname) {
    return $self->{topics}{ $topicname };
  }
  else {
    confess "topic name is required";
  }
}

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

sub version {
  say "todo $VERSION";

  exit 0;
}

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

sub loadfile {
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
  my $ca_defaults = {};

  ## set default verbosity, if specified in file
  if (defined $ca_settings->{verbose}) {
    if (ref($ca_settings->{verbose}) eq '') {
      $ca_defaults->{verbose} = 0 + $ca_settings->{verbose};
    }
  }

  return (1, $ca_defaults);
}

__END__
