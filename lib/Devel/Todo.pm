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

  my $n_self = {
    TODO_FILE => $n_todo_file,
    PROJECT   => LoadFile($n_todo_file),
    SETTINGS  => {
      STATUS              => ($n_config->{STATUS}
          || die "no status given"),
      DEFAULT_STATUS      => ($n_config->{DEFAULT_STATUS}
          || die "no default status given"),
      DEFAULT_PRIORITY    => $n_config->{DEFAULT_PRIORITY} || 0,
      DEFAULT_DESCRIPTION => $n_config->{DEFAULT_DESCRIPTION} || '',
      STATUS_OPT          => $n_config->{STATUS_OPT} || '',
      PRIORITY_OPT        => $n_config->{PRIORITY_OPT} || '',
      DESCRIPTION_OPT     => $n_config->{DESCRIPTION_OPT} || '',
      MOVE_ENABLED        => $n_config->{MOVE_ENABLED} || 1,
      VERBOSE             => $n_config->{VERBOSE} || 0,
    },
  };

  bless $n_self, $n_class;
}

# does list item have a status?
sub _has_the_status {
  my ($elem, $cmp_status, $status, $default_status) = @_;

  return 1 if ($status eq 'all');

  if (ref($elem) eq "HASH") {
    if (exists $elem->{status} && defined $elem->{status}) {
      return ($cmp_status eq $elem->{status});
    }
    else {
      return ($default_status eq $cmp_status);
    }
  }
  else {
    return ($cmp_status eq $elem);
  }
}

# does todo list have item named after key?
sub has_element {
  my ($he_self, @he_keys) = @_;

  return 0 unless @he_keys;

  if (scalar @he_keys == 1) {
    return (exists $he_self->{PROJECT}{contents}{$he_keys[0]});
  }
  else {
    if (exists $he_self->{PROJECT}{contents}{$he_keys[0]}) {
      my $he_sublist = $he_self->{PROJECT}{contents}{$he_keys[0]};

      if (isa_list($he_sublist)
        && exists $he_sublist->{contents}{$he_keys[1]}) {
      
        return 1;
      }
    }

    return 0;
  }
}

# is scalar a todo list?
sub isa_list {
  my ($val) = @_;

  return (ref($val) eq 'HASH' && exists $val->{contents}
    && ref($val->{contents}) eq 'HASH');
}

# create an item or maybe change an existing one
sub Add_Element {
  my ($ae_self, $ae_args) = @_;

  if ($ae_self->{SETTINGS}{STATUS} eq 'all') {
    die("error: cannot create with \'all\' status");
  }

  # construct a new list item
  my $ae_item = {};
  if ($ae_self->{SETTINGS}{PRIORITY_OPT} eq ''
    && $ae_self->{SETTINGS}{DESCRIPTION_OPT} eq '') {
    
    if ($ae_self->{SETTINGS}{STATUS_OPT} eq '') {
      $ae_item = $ae_self->{SETTINGS}{DEFAULT_STATUS};
    }
    else {
      $ae_item = $ae_self->{SETTINGS}{STATUS_OPT};
    }
  }
  elsif ($ae_self->{SETTINGS}{PRIORITY_OPT} eq '') {
    $ae_item->{description} = $ae_self->{SETTINGS}{DESCRIPTION_OPT};
  }
  elsif ($ae_self->{SETTINGS}{DESCRIPTION_OPT} eq '') {
    $ae_item->{priority} = $ae_self->{SETTINGS}{PRIORITY_OPT};
  }
  elsif ($ae_self->{SETTINGS}{STATUS_OPT} ne '') {
    $ae_item->{status} = $ae_self->{SETTINGS}{STATUS_OPT};
  }

  foreach (@$ae_args) {
    if ($ae_self->{SETTINGS}{MOVE_ENABLED}
      && $ae_self->apply_to_matches(\&_ae_mover, $_)) {

      next;
    }
    elsif (ref($_) eq 'ARRAY') {
      unless (defined $ae_self->{PROJECT}{contents}{ $_->[0] }) {
        $ae_self->{PROJECT}{contents}{ $_->[0] } = {
          contents => {}
        };
      }

      my $ae_sublist = $ae_self->{PROJECT}{contents}{ $_->[0] };
      
      # make several items with identical attributes in a sublist
      for my $ae_item_name (@{ $_->[1] }) {
        $ae_sublist->{contents}{$ae_item_name} = $ae_item;
      }
    }
    else {
      $ae_self->{PROJECT}{contents}{$_} = $ae_item;
    }
  }

  DumpFile($ae_self->{TODO_FILE}, $ae_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by add_element to move an item
sub _ae_mover {
  my ($project, $settings, $key) = @_;

  if (ref($project->{contents}{$key}) eq 'HASH') {
    $project->{contents}{$key}{status} = $settings->{STATUS};
  }
  else {
    $project->{contents}{$key} = $settings->{STATUS};
  }
}

# call a function on all relevant items
sub apply_to_matches {
  my ($atm_self, $atm_sub, $atm_key) = @_;

  if (ref($atm_key) eq 'ARRAY') {
    return 0 unless $atm_self->has_element($atm_key->[0]);

    my $atm_count   = 0;
    my $atm_sublist = $atm_self->{PROJECT}{contents}{ $atm_key->[0] };

    if (isa_list($atm_sublist)) {
      foreach (@{ $atm_key->[1] }) {
        if ($atm_self->has_element($atm_key->[0], $_)) {
          &{ $atm_sub }($atm_sublist, $atm_self->{SETTINGS}, $_);
        }
      }

      return $atm_count;
    }
  }
  elsif ($atm_self->has_element($atm_key)) {
    &{ $atm_sub }($atm_self->{PROJECT}, $atm_self->{SETTINGS}, $atm_key);
    
    return 1;
  }

  return 0;
}

# change relevant items 
sub Edit_Element {
  my ($ee_self, $ee_args) = @_;
  
  unless (isa_list($ee_self->{PROJECT})) {
    die('error: no todo list to work on');
  }

  if ($ee_self->{SETTINGS}{STATUS} eq 'all') {
    die("error: cannot edit with \'all\' status");
  }

  foreach (@$ee_args) {
    $ee_self->apply_to_matches(\&_ee_set_attrs, $_);
  }

  DumpFile($ee_self->{TODO_FILE}, $ee_self->{SETTINGS}, $ee_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by edit_element to change items
sub _ee_set_attrs {
  my ($list, $settings, $key) = @_;

  my $contents = $list->{contents};

  return if ($settings->{STATUS_OPT} eq '' 
          && $settings->{PRIORITY_OPT} eq ''
          && $settings->{DESCRIPTION_OPT} eq '');

  my $replacement = {};

  if (ref($contents->{$key}) eq 'HASH') {
    $replacement = $contents->{$key};
  }
  
  if ($settings->{STATUS_OPT} ne '') {
    $replacement->{status} = $settings->{STATUS_OPT};
  }

  if ($settings->{PRIORITY_OPT} ne '') {
    $replacement->{priority} = $settings->{PRIORITY_OPT};
  }

  if ($settings->{DESCRIPTION_OPT} ne '') {
    $replacement->{description} = $settings->{DESCRIPTION_OPT};
  }

  $contents->{$key} = $replacement;
}

# print information about items in list
sub Show_Element {
  my ($se_self, $se_args) = @_;

  die('error: nothing to show') unless (isa_list($se_self->{PROJECT}));

  if (scalar @$se_args) {
    foreach (@$se_args) {
      # ignore arrayref args
      if (ref($_) eq '') {
        $se_self->apply_to_matches(\&_se_dumper, $_);
      }
    }
  }
  else {
    _se_dumper($se_self->{PROJECT}, $se_self->{SETTINGS}, '');
  }

  return 0;
}

# print contents of 'list' if items have the right status
sub _se_dumper {
  my ($project, $settings, $key) = @_;

  my $has_printed_key = 0;
  $has_printed_key    = 1 if $key eq '';

  if ($key eq '') {
    # print each item, excluding sublists, if it has the right status
    # apply the same rule to the ITEMS of a sublist
    while ((my ($k, $v) = each %{ $project->{contents} })) {
      if (isa_list($v)) {
        _se_dumper($project, $settings, $k);
      }
      elsif (_has_the_status(
                $v,
                $settings->{STATUS},
                $settings->{STATUS},
                $settings->{DEFAULT_STATUS})) {

        print $k;

        if ($settings->{VERBOSE} == 1) {
          if (ref($v) eq 'HASH' && exists $v->{description}) {
            print " ($v->{description})";
          }
        }
        print "\n";
      }
    }
  }
  else {
    my $sublist = $project->{contents}{$key};

    return unless isa_list($sublist);

    while ((my ($k, $v) = each %{ $sublist->{contents} })) {
      if (_has_the_status(
              $v,
              $settings->{STATUS},
              $settings->{STATUS},
              $settings->{DEFAULT_STATUS})) {

        unless ($has_printed_key) {
          print $key, ':';

          if ($settings->{VERBOSE} == 1
            && exists $sublist->{description}) {
            
            print " ($sublist->{description}";
          }          
          print "\n";

          $has_printed_key = 1;
        }

        print '  ', $k;

        if ($settings->{VERBOSE} == 1) {
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

  die('error: nothing to delete') unless isa_list($de_self->{PROJECT});

  my $de_contents = $de_self->{PROJECT}{contents};
  if (scalar @$de_args) {
    foreach (@$de_args) {
      $de_self->apply_to_matches(\&_de_deleter, $_);
    }
  }
  else {
    for my $key (keys %{$de_contents}) {
      if (_has_the_status(
              $de_contents->{$key},
              $de_self->{SETTINGS}{STATUS},
              $de_self->{SETTINGS}{STATUS},
              $de_self->{SETTINGS}{DEFAULT_STATUS})) {

        delete $de_contents->{$key};
      }
      elsif (isa_list($de_contents->{$key})) {
        while ((my ($subkey, $subvalue) = each %{ $de_contents->{$key}{contents} })) {
          _de_deleter($de_contents->{$key}, $de_self->{SETTINGS}, $subkey);
        }
      }
    }
  }

  DumpFile($de_self->{TODO_FILE}, $de_self->{PROJECT});

  return 0;
}

# passed to apply_to_matches by delete_element to remove an item
sub _de_deleter {
  my ($project, $settings, $key) = @_;

  if (_has_the_status(
          $project->{contents}{$key},
          $settings->{STATUS},
          $settings->{STATUS},
          $settings->{DEFAULT_STATUS})) {

    delete $project->{contents}{ $key };
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
  ['code', 'Devel::Todo']
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
the sub must be prepared to take three arguments: 1) a hash reference
that points to the start of the list or the current sublist, 2) the
project settings, which have the same keys defined in $config passed
to new, 3) the string name of the element in the list or sublist. the
start of the list is the Entire YAML document.

=item has_element($name [, $subname])

predicate. check for existence of an element in the list
or in a sublist

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
