#!/usr/bin/env perl

package Project::Task::ListTask;

use Mouse;
extends qw/Project::Task/;

has "contents" => { is => "rw", isa => "ArrayRef" };

sub execute {
  my ($self, $action) = @_;

  unless (defined $action) {
    $action = sub { return "$_[0]->name: $_[0]->summary"; };
  }

  foreach (@{ $self->contents }) {
    if (blessed $_ eq "Project::Task::ListTask") {
      $_->execute($action);
    }
    else {
      $action->($_);
    }
  }
}
