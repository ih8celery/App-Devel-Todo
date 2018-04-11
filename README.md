# Name

todo -- manage your todo list

    todo [global options] [subcommand] [options] [arguments]

# Summary

`todo` helps you manage your todo list. your list is a YAML file, which
does not really contain a list, but a hash table. your list is composed
of items. an item has a name, which is the key to the hash table, and at
least one attribute, its status. see the example below.

    ---
    name: today
    contents:
      wake: did
      eat: want
      sleep: do
      code:
        status: do
    ...

the above yaml snippet shows two ways to set the status: as the value of
the item in the document's **contents** hash; and as the value of the
key below the item. either approach is valid. note that in any case,
every item **must** be assigned a status. status is a way of describing
the current condition of an item. by default, you may choose from three
statuses: "do", "did", and "want". incidentally, the "subcommand" you
use corresponds to the status of the items you want to create, see,
delete, or edit.

the status is one of three possible attributes that an item may have.
unlike the status attribute, these attributes need not be present in an item.
the other two attributes are priority, a positive integer, and description.
a priority of zero is the default and is the 'first' priority, much as
zero is the first index of arrays in most programming languages. the
description is simply a string which should be used to clarify the
meaning of an item.

items may contain an additional member: contents. the presence of this
key indicates that an item is a todo list in its own right. such a
sublist may contain items just like its parent, with one exception:
further sublists. 

    ---
    name: tomorrow
    contents:
      wake: do
      eat: want
      other:
        status: do
        contents:
          walk my dog: do
          sacrifice to Odin: do
    ...

notice that both the parent todo list and its sublist 'other' have a
_contents_ key. the contents key is required for a list to be
recognized.

# Subcommands

before you ask, the subcommands are not in fact "commands"; the actual
commands reside among the regular options. you may attribute this mangling
of convention to three lines of reasoning: first, I believed that the order
of command-line arguments should correspond to how I formulate a todo in
my own mind. I think first that I should **do** foo, not **add** foo to
the list of items that I must do. secondly, I found that using status
instead of true commands better facilitated my two most common use
cases: looking at everything in a list with a particular status, and
adding a new item somewhere. for comparison, 

    todo do     # shows everything with "do" status
    todo do foo # adds a new item called foo with "do" status

allows me to differentiate between showing and adding items simply by
the presence or absence of additional arguments. but

    todo show --do
    todo add --do foo

requires an extra piece of information in most cases (if "do" were the
default status we could shorten this example by removing `--do`,
but this still leaves the other statuses. finally, I wanted to allow
users to define new statuses particular to how they work, which would
be easier to support if the status had to appear as the first argument
to `todo`.

NOTE: except for 'all', the subcommand sets the default status used by the
program

the following subcommands are automatically defined:

- do

    select items with "do" status

- did

    select items with "did" status

- want

    select items with "want" status

- all

    select everything, regardless of status

# General Options

- -h|--help

    print help. if this option is supplied first, general help concerning
    the options is printed. otherwise, it will print help for the current
    subcommand

- -v|--version

    print application version information

- -S|--show

    print item/s from the currently selected list

- -E|--edit

    change list item information

- -C|--create

    add new item/s to selected list or move from another list

- -N|--create-no-move

    add new item/s to selected list without the possibility of moving
    from another list

- -D|--delete

    remove item/s from selected list. 

- -s|--use-status

    specify a status. this is relevant when creating or editing items,
    and it is different from the status set by the subcommand

- -d|--use-description

    specify a description. this is relevant when creating or editing items

- -p|--use-priority

    specify a priority. this is relevant when creating or editing items

- -f|--config-file

    specify a different file to use as configuration file

- -t|--todo-file

    specify a different file to use as project todo list

# Arguments

arguments are used to identify items and groups of items. there are
three types of arguments:

- keys

    Example: vim.

    to be a key, an argument string must end on a '.'
    a key starts a new sublist named after the key to which 
    values will be added

- values

    Example: "read vim-perl help"

    to be a value, an argument must simply not contain a '.'.
    added to the list or a sublist, if one is active. add a description
    to a value by following it with '='

- key-value pairs

    examples: vim."read vim-perl help", vim.perl="read vim-perl help"

    a key-value pair is a string with two parts separated by a '.'
    adds to a sublist named after the key, creating the sublist if it does
    not exist. add a description to a value by following it with '='

# Examples

todo do "eat something"

todo do "eat something" "walk the dog"

todo do exercise

todo do todo-app. "implement create" "implement delete" "implement show"

todo want -S

todo do -D todo-app."implement show"

# Copyright and License

Copyright (C) 2018 Adam Marshall.
This software is distributed under the MIT License
