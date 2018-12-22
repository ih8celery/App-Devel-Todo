#!/usr/bin/env perl

package Project::Task::ListTask;

use strict;
use warnings;

use YAML qw/LoadFile DumpFile/;

use Mouse;
extends qw/Project::Task/;

has 'contents' => { is => 'rw', isa => 'ArrayRef' };

# given list of names, find a ListTask under $self
sub find {
  my ($self, @path) = @_;
  my $task = $self;

  return $task unless (scalar @path && $path[0] ne '');

  foreach (@path) {
    for my $subtask (@{ $task->contents }) {
      if ($subtask->name eq $_) {
        $task = $subtask;
        last;
      }
    }

    if (!defined($task) || blessed($task eq 'Project::Task::SimpleTask')) {
      return undef;
    }
  }

  return $task;
}

sub execute {
  my ($self, $subtaskName) = @_;

  if (defined $subtaskName) {
    my $task = $self->find($subtaskName);

    if (defined $task) {
      $task->execute;
    }
    else {
      confess 'cannot execute task that does not exist';
    }
  }
  else {
    foreach (@{ $self->contents }) {
      $_->execute;
    }
  }
}

sub describe {
  my ($self, $subtaskName) = @_;

  if (defined $subtaskName) {
    my $task = $self->find($subtaskName);

    if (defined $task) {
      $task->describe;
    }
    else {
      confess 'cannot describe task that does not exist';
    }
  }
  else {
    foreach (@{ $self->contents }) {
      $_->describe;
    }
  }
}

sub remove {
  my ($self, $childName) = @_;
  
  # check childName defined
  confess '$childName required by remove method'
    unless defined $childName;

  # check childName present under self
  my @arr = @{ $self->{contents} };
  my $ind = -1;
  for (my $i = 0; $i < scalar @arr; $i++) {
    if ($arr[ $i ]->name eq $childName) {
      $ind = $i;
      last;
    }
  }

  confess "$childName does not exist in list"
    if $ind = -1;

  # delete element from this list's contents
  delete $self->{contents}->[ $ind ];
}

sub insert {
  my ($self, $childAttrs) = @_;
  
  # check name exists <- name is required
  unless (exists $childAttrs->{name}) {
    confess 'name is required to insert Task into ListTask';
  }

  # make sure name is not under $self
  foreach (@{ $self->{contents} }) {
    if ($_->name eq $childAttrs->{name}) {
      confess 'task name must not already be present in ListTask to insert a Task';
    }
  }

  # check contents to decide which class to create and add attrs
  if (defined $childAttrs->{contents}) {
    # create root task and call insert on contents
    my $task = Project::Task::ListTask(
      name    => $childAttrs->{name},
      summary => $childAttrs->{summary},
      taglist => $childAttrs->{taglist}
    );

    foreach (@{ $childAttrs->{contents} }) {
      $task->insert($_);
    }
  }
  else {
    return Project::Task::SimpleTask(%$childAttrs);
  }
}

sub loadfile {
  my ($class, $file) = @_;

  my $hash = LoadFile($file);

  # create root task
  my $rootTask = Project::Task::ListTask(
    name     => $hash->{name},
    summary  => $hash->{summary},
    taglist  => $hash->{taglist}
  );

  # insert contents array into rootTask
  foreach (@{ $hash->{contents} }) {
    $rootTask->insert($_);
  }

  return $rootTask;
}

sub dumpfile {
  my ($self, $file) = @_;

  DumpFile($file, $self);
}
