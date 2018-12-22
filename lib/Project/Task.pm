#!/usr/bin/env perl

package Project::Task;

use strict;
use warnings;

use Mouse;

has 'name'    => { is => 'rw', isa => 'Str' };
has 'summary' => { is => 'rw', isa => 'Str' };
has 'taglist' => { is => 'bare', isa => 'HashRef' };

sub tag {
  my ($self, $tagname) = @_;

  if (defined $tagname) {
    $self->{taglist}{ $tagname } = 1;
  }
  else {
    confess 'tagname is not defined';
  }
}

sub untag {
  my ($self, $tagname) = @_;

  delete $self->{taglist}{ $tagname };
}

sub has_tag {
  my ($self, $tagname) = @_;

  return (exists $self->{taglist}{ $tagname }) && ($self->{taglist}{ $tagname } == 1);
}

__END__
