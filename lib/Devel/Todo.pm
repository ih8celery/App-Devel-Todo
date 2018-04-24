#! /usr/bin/env perl
# file: Devel/Todo.pm
# author: Adam Marshall (ih8celery)
# brief: define Devel::Todo class

package Devel::Todo;

use strict;
use warnings;

use feature qw/say/;

use YAML::XS qw/LoadFile DumpFile/;

our $VERSION = '0.006001';

# construct a new Devel::Todo object
sub new {
  my ($n_class, $n_todo_file, $n_config) = @_;

  my $n_yaml = LoadFile($n_todo_file);

  my $n_self = {
    TODO_FILE => $n_todo_file,
    NAME      => ($n_yaml->{name} || ''),
    PROJECT   => ($n_yaml->{contents} || die "no project"),
    STATUS    => ($n_config->{STATUS} || die "no status given"),
    DEFAULT_STATUS => ($n_config->{DEFAULT_STATUS}
          || die "no default status given"),
    DEFAULT_PRIORITY    => $n_config->{DEFAULT_PRIORITY} || 0,
    DEFAULT_DESCRIPTION => $n_config->{DEFAULT_DESCRIPTION} || '',
    STATUS_OPT          => $n_config->{STATUS_OPT} || '',
    PRIORITY_OPT        => $n_config->{PRIORITY_OPT} || '',
    DESCRIPTION_OPT     => $n_config->{DESCRIPTION_OPT} || '',
    MOVE_ENABLED        => $n_config->{MOVE_ENABLED} || 1,
    VERBOSE             => $n_config->{VERBOSE} || 0,
  };

  bless $n_self, $n_class;
}

# does list item have a particular status?
sub has_status {
  my ($hs_self, $hs_elem, $hs_status) = @_;

  return 1 if ($hs_self->{STATUS} eq 'all');

  if (ref($hs_elem) eq "HASH") {
    if (exists $hs_elem->{status} && defined $hs_elem->{status}) {
      return ($hs_status eq $hs_elem->{status});
    }
    else {
      return ($hs_self->{DEFAULT_STATUS} eq $hs_status);
    }
  }
  else {
    return ($hs_status eq $hs_elem);
  }
}

sub file {
  return ($_[0]->{TODO_FILE});
}

sub contents {
  my ($l_self, $l_key) = @_;

  if (defined $l_key && $l_self->has_element($l_key)) {
    my $l_element = $l_self->{PROJECT}{$l_key};

    if ($l_self->isa_list($l_element)) {
      return $l_element->{contents};
    }
    else {
      return {};
    }
  }
  else {
    return $l_self->{PROJECT};
  }
}

sub get_element {
  my ($ge_self, @ge_keys) = @_;

  return {} unless $ge_self->has_element(@ge_keys);

  if (scalar @ge_keys == 1) {
    return $ge_self->{PROJECT}{$ge_keys[0]};
  }
  else {
    return $ge_self->contents($ge_keys[0])->{$ge_keys[1]};
  }
}

sub set_element {
  my ($se0_self, $se0_element, @se0_keys) = @_;

  return unless $se0_self->has_element(@se0_keys);

  if (scalar @se0_keys == 1) {
    $se0_self->{PROJECT}{$se0_keys[0]} = $se0_element;
  }
  else {
    $se0_self->contents($se0_keys[0])->{$se0_keys[1]} = $se0_element;
  }

}

# save the project to a file
sub save_project {
  DumpFile($_[0]->{TODO_FILE}, { 
      name => $_[0]->{name},
      contents => $_[0]->{PROJECT}
    });
}

# does todo list have item named after key?
sub has_element {
  my ($he_self, @he_keys) = @_;

  return 0 unless @he_keys;

  if (scalar @he_keys == 1) {
    return (exists $he_self->{PROJECT}{$he_keys[0]});
  }
  else {
    if (exists $he_self->{PROJECT}{$he_keys[0]}) {
      my $he_sublist = $he_self->{PROJECT}{$he_keys[0]};

      if ($he_self->isa_list($he_sublist)
        && exists $he_sublist->{contents}{$he_keys[1]}) {
      
        return 1;
      }
    }

    return 0;
  }
}

# is scalar a todo list?
sub isa_list {
  my ($il_self, $il_val) = @_;

  return (ref($il_val) eq 'HASH' && exists $il_val->{contents}
    && ref($il_val->{contents}) eq 'HASH');
}

# is scalar an empty todo list?
sub is_empty_list {
  my ($iel_self, $iel_val) = @_;

  return ($iel_self->isa_list($iel_val)
    && !(scalar keys %{ $iel_val->{contents} }));
}

# get a hash reference to a copy of an element's attributes
sub get_attributes {
  my ($ga_self, @ga_keys) = @_;

  return {} unless (@ga_keys && $ga_self->has_element(@ga_keys));

  my $ga_out = {};
  my $ga_element = $ga_self->get_element(@ga_keys);

  if (ref($ga_element) eq '') {
    $ga_out->{status} = $ga_element;
  }
  else {
    if (exists $ga_element->{status}) {
      $ga_out->{status} = $ga_element->{status};
    }
    else {
      $ga_out->{status} = $ga_self->{DEFAULT_STATUS};
    }

    if (exists $ga_element->{priority}) {
      $ga_out->{priority} = $ga_element->{priority};
    }

    if (exists $ga_element->{description}) {
      $ga_out->{description} = $ga_element->{description};
    }
  }

  return $ga_out;
}

# create an item or maybe change an existing one
sub Add_Element {
  my ($ae_self, $ae_args) = @_;

  if ($ae_self->{STATUS} eq 'all') {
    die("error: cannot create with \'all\' status");
  }

  # construct a new list item
  my $ae_elem = {};
  if ($ae_self->{PRIORITY_OPT} eq ''
    && $ae_self->{DESCRIPTION_OPT} eq '') {
    
    if ($ae_self->{STATUS_OPT} eq '') {
      $ae_elem = $ae_self->{DEFAULT_STATUS};
    }
    else {
      $ae_elem = $ae_self->{STATUS_OPT};
    }
  }
  elsif ($ae_self->{PRIORITY_OPT} eq '') {
    $ae_elem->{description} = $ae_self->{DESCRIPTION_OPT};
  }
  elsif ($ae_self->{DESCRIPTION_OPT} eq '') {
    $ae_elem->{priority} = $ae_self->{PRIORITY_OPT};
  }
  elsif ($ae_self->{STATUS_OPT} ne '') {
    $ae_elem->{status} = $ae_self->{STATUS_OPT};
  }

  foreach (@$ae_args) {
    if ($ae_self->{MOVE_ENABLED}
      && $ae_self->apply_to_matches(\&_ae_mover, $_)) {

      next;
    }
    elsif (ref($_) eq 'ARRAY') {
      unless ($ae_self->has_element($_->[0])) {
        $ae_self->{PROJECT}{ $_->[0] } = {
              contents => {}
        };
      }

      my $ae_sublist = $ae_self->get_element($_->[0]);
      
      # make several items with identical attributes in a sublist
      for my $ae_name (@{ $_->[1] }) {
        $ae_sublist->{contents}{$ae_name} = $ae_elem;
      }
    }
    else {
      $ae_self->{PROJECT}{$_} = $ae_elem;
    }
  }

  $ae_self->save_project();

  return 0;
}

# passed to apply_to_matches by add_element to move an item
sub _ae_mover {
  my ($self, @keys) = @_;

  if (ref($self->get_element(@keys)) eq 'HASH') {
    $self->get_element(@keys)->{status} = $self->{STATUS};
  }
  else {
    $self->set_element($self->{STATUS}, @keys);
  }
}

# call a function on all relevant items
sub apply_to_matches {
  my ($atm_self, $atm_sub, $atm_key) = @_;

  if (ref($atm_key) eq 'ARRAY') {
    return 0 unless $atm_self->has_element($atm_key->[0]);

    my $atm_count   = 0;
    my $atm_sublist = $atm_self->get_element($atm_key->[0]);

    if ($atm_self->isa_list($atm_sublist)) {
      foreach (@{ $atm_key->[1] }) {
        if ($atm_self->has_element($atm_key->[0], $_)) {
          &{ $atm_sub }($atm_self, $atm_key->[0], $_);

          $atm_count++;
        }
      }

      return $atm_count;
    }
  }
  elsif ($atm_self->has_element($atm_key)) {
    &{ $atm_sub }($atm_self, $atm_key);
    
    return 1;
  }

  return 0;
}

# change relevant items 
sub Edit_Element {
  my ($ee_self, $ee_args) = @_;
  
  if ($ee_self->{STATUS} eq 'all') {
    die("error: cannot edit with \'all\' status");
  }

  foreach (@$ee_args) {
    $ee_self->apply_to_matches(\&_ee_set_attrs, $_);
  }

  $ee_self->save_project();

  return 0;
}

# passed to apply_to_matches by edit_element to change items
sub _ee_set_attrs {
  my ($self, @keys) = @_;

  # return if the user did not provide values for *_OPT vars
  return if ($self->{STATUS_OPT} eq '' 
          && $self->{PRIORITY_OPT} eq ''
          && $self->{DESCRIPTION_OPT} eq '');

  my $replacement = {};

  if (ref($self->get_element(@keys)) eq 'HASH') {
    $replacement = $self->get_element(@keys);
  }
  
  if ($self->{STATUS_OPT} ne '') {
    $replacement->{status} = $self->{STATUS_OPT};
  }

  if ($self->{PRIORITY_OPT} ne '') {
    $replacement->{priority} = $self->{PRIORITY_OPT};
  }

  if ($self->{DESCRIPTION_OPT} ne '') {
    $replacement->{description} = $self->{DESCRIPTION_OPT};
  }

  $self->set_element($replacement, @keys);
}

# print information about items in list
sub Show_Element {
  my ($se1_self, $se1_args) = @_;

  if (scalar @$se1_args) {
    foreach (@$se1_args) {
      # ignore arrayref args
      if (ref($_) eq '') {
        $se1_self->apply_to_matches(\&_se1_dumper, $_);
      }
    }
  }
  else {
    _se1_dumper($se1_self, '');
  }

  return 0;
}

# print contents of 'list' if items have the right status
sub _se1_dumper {
  my ($self, @keys) = @_;

  my $has_printed_key = 0;
  $has_printed_key    = 1 if $keys[0] eq '';

  if ($keys[0] eq '') {
    # print each item, excluding sublists, if it has the right status
    # apply the same rule to the ITEMS of a sublist
    while ((my ($k, $v) = each %{ $self->{PROJECT} })) {
      if ($self->isa_list($v)) {
        _se1_dumper($self, $k);
      }
      elsif ($self->has_status($v, $self->{STATUS})) {
        print $k;

        if ($self->{VERBOSE} == 1) {
          if (ref($v) eq 'HASH' && exists $v->{description}) {
            print " ($v->{description})";
          }
        }
        print "\n";
      }
    }
  }
  else {
    my $sublist = $self->get_element(@keys);

    return unless ($self->isa_list($sublist));

    while ((my ($k, $v) = each %{ $sublist->{contents} })) {
      if ($self->has_status($v, $self->{STATUS})) {

        unless ($has_printed_key) {
          print $keys[0], ':';

          if ($self->{VERBOSE} == 1
            && exists $sublist->{description}) {
            
            print " ($sublist->{description}";
          }          
          print "\n";

          $has_printed_key = 1;
        }

        print '  ', $k;

        if ($self->{VERBOSE} == 1) {
          if (ref($v) eq 'HASH' && exists $v->{description}) {
            print " ($v->{description})";
          }
        }
        print "\n";
      }
    }
  }
}

# remove relevant items
sub Delete_Element {
  my ($de_self, $de_args) = @_;

  my $de_contents = $de_self->{PROJECT};
  if (scalar @$de_args) {
    foreach (@$de_args) {
      $de_self->apply_to_matches(\&_de_deleter, $_);
    }
  }
  else {
    foreach (keys %$de_contents) {
      $de_self->apply_to_matches(\&_de_deleter, $_);
    }
  }

  $de_self->save_project();

  return 0;
}

# passed to apply_to_matches by delete_element to remove an item
sub _de_deleter {
  my ($self, @keys) = @_;

  my $elem = $self->get_element(@keys);
  # if an element of sublist, delete it if it has the current status
  # and then delete the sublist if it is empty
  if (scalar @keys > 1) {
    if ($self->has_status($elem, $self->{STATUS})) {
      delete $self->{PROJECT}{ $keys[0] }{contents}{ $keys[1] };
    }

    # an empty sublist is removed regardless of its explicit status
    if ($self->is_empty_list($elem)) {
      delete $self->{PROJECT}{ $keys[0] };
    }
  }

  # if a sublist, attempt to delete the elements of it and
  # then delete the sublist if it is empty
  elsif ($self->isa_list($elem)) {
    foreach (keys %{ $elem->{contents} }) {
      if ($self->has_status($elem->{contents}{$_}, $self->{STATUS})) {
        delete $elem->{contents}{$_};
      }
    }

    # an empty sublist is removed regardless of its explicit status
    if ($self->is_empty_list($elem)) {
      delete $self->{PROJECT}{ $keys[0] };
    }
  }

  # otherwise, delete the element if it has the current status
  else {
    if ($self->has_status($elem, $self->{STATUS})) {
      delete $self->{PROJECT}{ $keys[0] };
    }
  }
}

__END__

=head1 Name

Devel::Todo -- object-oriented library for manipulating YAML todo lists

=head1 Introduction

Devel::Todo is the object-oriented backend to App::Devel::Todo, a
command-line app. Devel::Todo is intended to manipulate YAML in a
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
        Devel::Todo pod: do
        Devel::Todo tests: do
        App::Devel::Todo tests: did
        App::Devel::Todo pod: did
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
App::Devel::Todo to find out how.

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

Devel::Todo provides four main features: adding new elements to a todo
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
  ['code', ['Devel::Todo']]
]

the Delete_Element method mentioned above will process $args by
searching for an element named 'eat', and then for a sublist named
'code', in which it will try to find an element called 'Devel::Todo'

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

construct a new Devel::Todo object by loading $file_path and
initializing the program data from $config.

=over 4

=item $file_path

$file_path is a valid path to a YAML file containing the project
todo list.

=item $config

$config is a hash reference containing default state of the
Devel::Todo object. new will die if $config does not provide
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
other values will corrupt the YAML object and confuse Devel::Todo later.
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
        Devel::Todo pod: do
        Devel::Todo tests: do
        App::Devel::Todo tests: did
        App::Devel::Todo pod: did
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

my $todos = Devel::Todo->new($file, $config);

$todos->Delete_Element(["code"]); # removes entire "code" sublist

$todos->Edit_Element(["eat"]); # status of "edit" element -> "want"

$todos->Show_Element([]); # prints nothing, because nothing matches
                          # the current status

$todos->Add_Element(["exercise"]); # creates new element with status
                                   # "want" because STATUS_OPT is defined
