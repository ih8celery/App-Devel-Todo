#!/usr/bin/env perl

package App::TaskMaster;

use strict;
use warnings;

use Mouse;
extends qw/CLI::CommandLineApp/;

has 'tasks'    => { is => 'rw', isa => 'HashRef' };
has 'taskfile' => { is => 'rw', isa => 'Str', default => '.tasks.yml' };

override 'execute', sub {
  my ($self, $action) = @_;

  my $parseContext = {
    name        => '',
    summary     => '',
    verbose     => 0,
    configfile  => ''
  };
  
  my $commandSchema = {
    commands => 'add|rm|desc|run',
    options  => {
      '--help|-h' => {
        summary => 'print this help message'
      },
      '--version|-v' => {
        summary => 'print version information'
      },
      '--verbose|-V' => {
        summary => "print additional info while running $self->name"
      },
      '--config|-c=s' => {
        name    => 'configfile',
        summary => 'set config file'
      },
      '--tasks|-t=s' => {
        name    => 'taskfile',
        summary => 'set file used to load tasks'
      },
      '--summary|-d=s' => {
        summary => 'set task summary'
      },
      '--name|-n=s' => {
        summary => 'set task name'
      },
      '--tags|-T=[s]' => {
        summary => 'set task tag list'
      }
    },
    args => []
  };

  my $info = $self->get_args($commandSchema, $parseContext);

  # print help if asked for
  if ($info->has_option('help')) {
    print "$self->name v$self->version\n";
    print "$self->summary\n";
    print "Commands: $commandSchema->{commands}";
    print "Options:\n";

    for my ($k, $v) (each $commandSchema->{options}) {
      print "\t$k  $v->{summary}\n";
    }

    exit 0;
  }

  # print version if asked for
  if ($info->has_option('version')) {
    print "$self->name v$self->version\n";
    exit 0;
  } 

  # load config
  $self->loadfile($self->configfile)
    if defined $self->configfile;

  # load task file
  my $tasksFile = $info->options('tasks');
  my $rootTask  = Project::Task::ListTask->loadfile($tasksFile);

  # get task information
  my $taskPath    = $info->args('name');
  my $taskSummary = $info->options('summary');
  my $taskType    = $info->options('type');
  my $taskTags    = $info->options('tags');

  # create list of names
  my @names    = split /\./, $taskPath;
  my $lastName = scalar @names ? pop @names : undef;

  # act on command
  my $cmd = $info->command->name;
  my $selectedTask = $rootTask->find(@names);

  confess "Task is not defined at path: $taskPath"
    unless defined $selectedTask;

  if ($cmd eq 'add') {
    $selectedTask->insert({
      name     => $taskPath,
      summary  => $taskSummary,
      taglist  => $taskTags,
      contents => ($taskType eq 'list' ? [] : undef)
    });

    $rootTask->dumpfile($self->taskfile);
  }
  elsif ($cmd eq 'desc') {
    $selectedTask->describe($lastName);
  }
  elsif ($cmd eq 'run') {
    $selectedTask->execute($lastName);
  }
  elsif ($cmd eq 'rm') {
    $selectedTask->remove($lastName);

    $rootTask->dumpfile($self->taskfile);
  }
};

__END__
