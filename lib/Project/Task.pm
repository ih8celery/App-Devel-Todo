#!/usr/bin/env perl

package Project::Task;

use strict;
use warnings;

our $VERSION = '0.020000';

use Mouse;
with qw{
  Project::Utils::Describable
  Project::Utils::Taggable
  Project::Utils::Executable
};

has "name"    => { is => "bare", isa => "Str" };
has "summary" => { is => "bare", isa => "Str" };
has "topics"  => { is => "bare", isa => "HashRef" };
has "taglist" => { is => "bare", isa => "HashRef" };

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
  my ($self, $topicname, $topicinfo) = @_;

  if (defined $topicname && defined $topicinfo) {
    $self->{topics}{ $topicname } = $topicinfo;
  }
  elsif (defined $topicname) {
    return $self->{topics}{ $topicname };
  }
  else {
    # complain about problems
  }
}

sub tag {
  my ($self, $tagname) = @_;

  if (defined $tagname) {
    $self->{taglist}{ $tagname } = 1;
  }
  else {
    # complain about problems
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

=head1 Name

Project::Task -- object-oriented library for manipulating YAML todo lists

=head1 Introduction

Project::Task is the object-oriented backend to App::Project::Task, a
command-line app. Project::Task is intended to manipulate YAML in a
particular format, which is best illustrated by an example:

  ---
  name: today
  contents:
    eat:
      status: do
      priority: 3
    sleep: want
    code:
      status: do
      priority: 0
      description: just a little more until this project is finished!
      contents:
        Project::Task pod: do
        Project::Task tests: do
        App::Project::Task tests: did
        App::Project::Task pod: did
  ...

although it is read into Perl as a hash reference, the document above
is loosely referred to as a "list". in this context, a list may have
a name and it must have contents, where a list's contents are defined
as a hash reference whose keys name items belonging to the list. in
the list above, "eat", "sleep", and "code" are items in the list, which
is named "today". a list may have an empty contents hash, in which case
the list is said to be empty.

elements or items of a list (or sublist, with one limitation) are pairs
that can occur in two forms differentiated by their values: in the first
form the value of a pair is a simple scalar taken to be the status of the
element. in the example, "sleep" has a status of "want". in the second
form, the value is a hash reference that enumerates the attributes of
the element. "eat" is a simple example of this form. "code", however,
illustrates that elements of this form may contain contents of their
own. these elements are known as sublists. sublist elements are just
like regular list elements, except that they may not themselves be
sublists. below is a summary of attributes to help you utilize the
two forms of elements effectively.

=over 4

=item * status

status is an essential characteristic of every element. you should
always specify your elements' status. status is used to find elements
affected by method calls. "do", "want", and "all" are automatically
defined for you, but you can create others. see the documentation for
App::Project::Task to find out how.

=item * priority

priority is the importance or urgency of an element. elements have
a default priority of 0. priority can be any positive integer. 0
is the highest priority.

Note: I do not currently do anything with priority, but it is in my
long term plans to integrate it into the search process.

=item * description

an element's description is exactly what it sounds like. you should
avoid long strings; if you find yourself writing long descriptions,
maybe you should create a sublist or a new project instead.

=back

Project::Task provides four main features: adding new elements to a todo
list with Add_Element; editing the attributes of existing elements
with Edit_Element; printing element names (and possibly descriptions)
to stdout with Show_Element; and removing elements from the todo list
with Delete_Element. each of these functions takes a single argument,
an array reference listing the names of elements which should be
affected by the method. to reach a sublist element, you need simply
embed another array reference within this argument that contains first
the name of the sublist and then the names of all the relevant elements.

let's illustrate with an example:

$args = [
  'eat',
  ['code', ['Project::Task']]
]

the Delete_Element method mentioned above will process $args by
searching for an element named 'eat', and then for a sublist named
'code', in which it will try to find an element called 'Project::Task'

=head1 API

Note on Convention: in this section you will notice that some method
names are partly capitalized and others do not contain any capital
letters. I use capitalization in this way to distinguish between the
two types of methods I define: workers, whose names contain no capital
letters, and drivers. note that the "new" method is a special case of
a driver which I have not capitalized because of existing convention
in the Perl community. a worker is a utility method used by the drivers
to accomplish their tasks: it should be short; it should be focused on
a single task; and it should report problems to its caller rather than
dying. conversely, drivers centrally control collections of behaviors
at the heart of what the program is intended to provide. drivers
implement features.

=over 4

=item new($file_path, $config)

construct a new Project::Task object by loading $file_path and
initializing the program data from $config.

=over 4

=item $file_path

$file_path is a valid path to a YAML file containing the project
todo list.

=item $config

$config is a hash reference containing default state of the
Project::Task object. new will die if $config does not provide
values for STATUS and DEFAULT_STATUS.

new looks for the following keys:
  STATUS              # the status used to search todo list
  DEFAULT_STATUS      # status automatically used to create or edit
  DEFAULT_PRIORITY    # priority used to create or edit
  DEFAULT_DESCRIPTION # description used to create or edit
  STATUS_OPT          # alternative to default status provided by user
  PRIORITY_OPT        # alternative to default priority
  DESCRIPTION_OPT     # alternative to default description
  MOVE_ENABLED        # if 1, conflicting items will be modified when
                      # creating
                      # if 0, those items will be completely replaced
  VERBOSE             # if 1, prints description when showing
                      # if 0, simply prints item names

=back

=item Add_Element($args)

if MOVE_ENABLED == 0:

for each of the items in the array reference $args, Add_Element will
construct a new element and insert it into the list or a sublist,
displacing any elements in that list or sublist with the same names.
if defined, the values of any of STATUS_OPT, PRIORITY_OPT, and
DESCRIPTION_OPT will be used in constructing the new elements;
otherwise, Add_Element will use DEFAULT_STATUS, DEFAULT_PRIORITY, and
DEFAULT_DESCRIPTION to do it.

if MOVE_ENABLED == 1:

Add_Element will modify existing elements in-place rather than
replacing them. note that if you do not specify new values for
some attributes, the old values will be preserved

=item Show_Element($args)

Show_Element may have been misnamed. it prints the elements of either
the whole list or particular sublists. arguments that do not name
sublists are therefore disregarded. if $args is empty, then Show_Element
will print the entire list.

=item Edit_Element($args)

use the values of PRIORITY_OPT, STATUS_OPT, and DESCRIPTION_OPT to
change the attributes of the elements named in $args. names of non-
existant elements are ignored.

=item Delete_Element($args)

remove all of the elements named in $args. names of non-existant
elements are ignored.

=item apply_to_matches($sub, $name)

apply_to_matches takes a code reference and an element "name",
which is basically one element of the $args taken by Add_Element,
and runs the code on each affected element. you can use this method
to create your own custom drivers (and in fact Add_Element et al. are
all of them implemented on top of this method). to make this possible,
the sub must be prepared to take two arguments: 1) a copy of $self, and
2) a list of keys (either 1 or 2) that specifies the location of the
affected element.

=item has_element($name [, $subname])

predicate. check for existence of an element in the list
or in a sublist

=item get_attributes($name [, $subname])

get a hash reference containing copies of the defined attributes
of an element. the result can hold at most values for 'status',
'priority', and 'description'. if an element does not directly
specify its status, the default status is assumed. if the
arguments to get_attributes specify an element that does not exist,
the function returns an empty hash. NOTE: if an attribute is
not defined, no value for it will exist in the hash.

=item has_status($element, $status)

predicate. convenience method to test the status of an element 
in the YAML object. $element is the literal element, not its
name.

=item get_element(@keys)

retrieve the literal element specified by @keys. this will return
either a hash reference or a string, depending on the value of the
element. if the element does not exist, returns {}.

=item set_element($element, @keys)

sets the value of the element in the YAML object specified by @keys
to $element. valid forms of $element are a string and a hash reference.
other values will corrupt the YAML object and confuse Project::Task later.
by definition, set_element autovivifies an element that does not exist
and Replaces one that does exist.

=item file()

returns the path of the YAML project file

=item contents($name)

returns the contents hash reference of a sublist

=item save_project()

writes the current state of the project to the YAML file

=back

=head1 Examples

the file looks like this:
  ---
  name: today
  contents:
    eat:
      status: do
      priority: 3
    sleep: want
    code:
      status: do
      priority: 0
      description: just a little more until this project is finished!
      contents:
        Project::Task pod: do
        Project::Task tests: do
        App::Project::Task tests: did
        App::Project::Task pod: did
  ...


my $config = {
      STATUS              => "do",
      DEFAULT_STATUS      => "do",
      DEFAULT_PRIORITY    => 0,
      DEFAULT_DESCRIPTION => '',
      STATUS_OPT          => "want",
      PRIORITY_OPT        => 0,
      DESCRIPTION_OPT     => '',
      MOVE_ENABLED        => 1,
      VERBOSE             => 0,
};

my $todos = Project::Task->new($file, $config);

$todos->Delete_Element(["code"]); # removes entire "code" sublist

$todos->Edit_Element(["eat"]); # status of "edit" element -> "want"

$todos->Show_Element([]); # prints nothing, because nothing matches
                          # the current status

$todos->Add_Element(["exercise"]); # creates new element with status
                                   # "want" because STATUS_OPT is defined
#!/usr/bin/env perl

package Devel::Task::Configurable;

use Moose::Role;
use Devel::Task::Loadable;

requires qw/property loadfile/;

sub property {
  my ($self, $propname) = @_;

  return $self->{properties}{ $propname };
}
#!/usr/bin/env perl

package Devel::Task::Describable;

use Moose::Role;
requires qw/name summary info/;

sub info {
  my ($self, $topic) = @_;

  if (exists $self->{topics}{ $topic }) {
    return $self->{topics}{ $topic };
  }
  else return undef;
}
#!/usr/bin/env perl

package Devel::Task::Executable;

use Moose::Role;
requires qw/execute/;

sub execute {
  return $self->{action}->();
}
#!/usr/bin/env perl

package Devel::Task::ListTask;

use Moose;
extends qw/Task/;

has "subtasks" => { is => "bare", isa => "ArrayRef" };

override "execute", sub {
  my ($self) = @_;

  foreach (@{ $self->{subtasks} }) {
    $_->execute;
  }
};
#!/usr/bin/env perl

package Devel::Task::SimpleTask;

use Moose;
extends qw/Task/;

override "execute", sub {
  my ($self) = @_;

  print "$self->name: $self->summary";
};
#!/usr/bin/env perl

package Devel::Task::Taggable;

use Moose::Role;
requires qw/tag untag has_tag/;

has "tags" => { is => "bare", isa => "HashRef" };

sub tag {
  my ($self, $tagname) = @_;

  $self->{tags}{ $tagname } = 1;
}

sub untag {
  my ($self, $tagname) = @_;

  delete $self->{tags}{ $tagname } if exists $self->{tags}{ $tagname };
}

sub has_tag {
  my ($self, $tagname) = @_;

  return (exists $self->{tags}{ $tagname } && $self->{tags}{ $tagname } == 1);
}
