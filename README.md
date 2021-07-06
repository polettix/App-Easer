# NAME

App::Easer - Simplify writing (hierarchical) CLI applications

# VERSION

This document describes App::Easer version {{\[ version \]}}.

<div>
    <a href="https://travis-ci.org/polettix/App-Easer">
    <img alt="Build Status" src="https://travis-ci.org/polettix/App-Easer.svg?branch=master">
    </a>
    <a href="https://www.perl.org/">
    <img alt="Perl Version" src="https://img.shields.io/badge/perl-5.24+-brightgreen.svg">
    </a>
    <a href="https://badge.fury.io/pl/App-Easer">
    <img alt="Current CPAN version" src="https://badge.fury.io/pl/App-Easer.svg">
    </a>
    <a href="http://cpants.cpanauthors.org/dist/App-Easer">
    <img alt="Kwalitee" src="http://cpants.cpanauthors.org/dist/App-Easer.png">
    </a>
    <a href="http://www.cpantesters.org/distro/O/App-Easer.html?distmat=1">
    <img alt="CPAN Testers" src="https://img.shields.io/badge/cpan-testers-blue.svg">
    </a>
    <a href="http://matrix.cpantesters.org/?dist=App-Easer">
    <img alt="CPAN Testers Matrix" src="https://img.shields.io/badge/matrix-@testers-blue.svg">
    </a>
</div>

# SYNOPSIS

    #!/usr/bin/env perl
    use v5.24;
    use experimental 'signatures';
    use App::Easer 'run';
    my $app = {
       commands => {
          MAIN => {
             name => 'main app',
             help => 'this is the main app',
             description => 'Yes, this really is the main app',
             options => [
                {
                   name => 'foo',
                   description => 'option foo!',
                   getopt => 'foo|f=s',
                   environment => 'FOO',
                   default => 'bar',
                },
             ],
             execute => sub ($global, $conf, $args) {
                my $foo = $conf->{foo};
                say "Hello, $foo!";
                return 0;
             },
             'default-child' => '', # run execute by default
          },
       },
    };
    exit run($app, [@ARGV]);

Call examples:

    $ ./example.pl
    Hello, bar!
    
    $ ./example.pl --foo World
    Hello, World!
    
    $ ./example.pl commands
    $ perl lib/App/Easer.pm commands
               help: print a help message
           commands: list sub-commands
    
    $ ./example.pl help
    this is the main app
    
    Description:
        Yes, this really is the main app
    
    Options:
                foo: 
                     command-line: mandatory string option
                                   --foo <value>
                                   -f <value>
                     environment : FOO
                     default     : bar
    
    Sub commands:
               help: print a help message
           commands: list sub-commands
    
    $ ./example.pl help help
    print a help message
    
    Description:
        print help for (sub)command
    
    This command has no options.
    
    $ ./example.pl help commands
    list sub-commands
    
    Description:
        Print list of supported sub-commands
    
    This command has no options.
    
    $ ./example.pl inexistent
    cannot find sub-command 'inexistent'
    
    $ ./example.pl help inexistent
    cannot find sub-command 'inexistent'

# DESCRIPTION

**NOTE**: this software should be considered "late alpha" maturity. I'm
mostly happy with the interface, but there are still a few things that
might get changed. _Anyway_, if you find a release of `App::Easer` to
work fine for you, it's fair to assume that you will not need to get a
newer one later.

App::Easer provides the scaffolding for implementing hierarchical
command-line applications in a very fast way.

It makes it extremely simple to generate an application based on
specific interfacing options, while still leaving ample capabilities for
customising the shape of the application. As such, it aims at making
simple things easy and complex things possible, in pure Perl spirit.

An application is defined through a hash reference (or something that
can _be transformed_ into a hash reference, like a JSON-encoded string
containing an object, or Perl code) with the description of the
different aspects of the application and its commands.

By default, only commands need to be provided, each including metadata
for generating a help message, taking parameters from the command line
or other sources (e.g. environment variables), sub-commands, etc., as
well as the actual code to run when the command must be run.

## Application High Level View

The following YAML representation gives a view of the structure of an
application managed by `App::Easer`:

    factory:
       create: «executable»
       prefixes: «hash or array of hashes»
    configuration:
       collect:  «executable»
       merge:    «executable»
       validate: «executable»
       sources:  «array»
       'auto-children':  «false or array»
       'help-on-stderr': «boolean»
       'auto-leaves':    «boolean»
    commands:
       cmd-1:
          «command definition»
       cmd-2:
          «command definition»
       MAIN:
          «command definition»

Strictly speaking, only the `commands` section is needed in defining an
application; all other parts only deal with _customizing_ the behaviour
of `App::Easer` itself and take sensible defaults when not provided.

## Anatomy of a run

When an application is run, the following high level algorithm is
followed, assuming the initial command is defined as `MAIN`:

- the specification of the command is taken and option values for that
command are gathered, _consuming_ part of the command-line arguments;
- the configuration is optionally validated;
- a _commit_ hook is optionally called, allowing an intermediate command
to perform some actions before a sub-command is run;
- a sub-command is searched and, if present, the process restarts from the
first step above
- when the final sub-command is reached, its `execute` function is run.

## Factory and Executables

    factory:
       create: «executable»
       prefixes: «hash or array of hashes»

Many customization options appear as `«executable»`.

At the basic level, these can be just simple references to a sub. In
this case, it is used directly.

When they are provided in some other form, though, a _factory_ function
is needed to turn that alternative representation into a sub reference.

`App::Easer` comes with a default _factory_ function (described below)
that should cover most of the needs. It is possible to override it by
setting the value for key `create` inside `factory`; the default
function is used to generate this new factory, which is then installed
to parse all other `«executable»` values in the definition.

The default factory manages the following representations:

- sub references are passed through directly;
- strings are first filtered according to the mapping/mappings provided by
the field `prefixes` in `factory`, then parsed to get the name of a
package and optionally the name of a sub in that package (each field
that carries an `«executable»` is associated to a default sub name).

The `prefixes` can be either a hash reference, or an array of hashes.
The latter allows setting an order for substitutions, e.g. to make sure
that prefix `::` is tried first if there is also prefix `:` defined:

    prefixes:
       - '::' : 'What::Ever::'
       - ':' :  'My::App::'

Otherwise, the _unordered_ nature of Perl hashes would risk that the
expansion associated to `:` is tried first, spoiling the result and
making it unpredictable.

By default, the `+` character prefix is associated to a mapping into
functions in `App::Easer` starting with `stock_`. As an example, the
string `+CmdLine` is expanded into `App::Easer::stock_CmdLine`, which
happens to be an existing function (used in parsing command-line
options). It is possible to suppress this expansion by setting a mapping
from `+` to `+` in the `prefixes`, although this will deviate from
the normal working of `App::Easer`.

## Configuration Parsing Customization

    configuration:
       collect:  «executable»
       merge:    «executable»
       validate: «executable»
       sources:  «array»
       'auto-children': «false or array»
       'help-on-stderr': «boolean»
       'auto-leaves':    «boolean»

One of the central services provided by `App::Easer` is the automatic
gathering of options values from several sources (command line,
environment, commands upper in the hierarchy, defaults). Another service
is the automatic handling of two sub-commands `help` and `commands` to
ease navigating in the hierarchy and get information on the
(sub)commands.

The configuration is collected by a function provided by `App::Easer`
that can be optionally overridden by setting a different executable for
`collect` under `configuration`. This of course requires
re-implementing the options value gathering from scratch.

The `merge` executable allows setting a function that merges several
hashes together. The default implementation operates at the higher level
of the hashes only, giving priority to the first hashes provided (in
order).

The `validate` executable allows setting a validator. By default the
validation is performed using [Params::Validate](https://metacpan.org/pod/Params::Validate) (if available, it is
anyway loaded only when needed).

It is possible to set several _sources_ for gathering options values,
setting them using the `sources` array. By default it is set to the
ordered list with `+CmdLine`, `+Environment`, `+Parent`, and
`+Default`, meaning that options from the command line will have the
highest precedence, then the environment, then whatever comes from the
parent command configuration, then default values if present.

As anticipated, the `help` and `commands` sub-commands are
automatically generated and associated to each command by default (more
or less). If this is not the desired behaviour, it is possible to either
disable the addition of the `auto-children` completely (by setting a
false value), or provide an array of children names that will be added
automatically to each command (again, more or less).

It should be noted that both `validate` and `sources` are also part of
the specific setup for each command. As such, they will be rarely set at
the higher `configuration` level and the whole `configuration` section
can normally be left out of an application's definition.

Option `help-on-stderr` allows printing the two stock helper
commands `help` and `commands` on standard error instead of standard
output (which is the default).

Option `auto-leaves` allows setting any command that has no _explicit_
sub-command as a leaf, which prevents it from getting a `help` and a
`commands` sub-command (or whatever has been put to override them).

## Commands Specifications

All commands are stored in a hash of hashes, where the key represents an
internal _identifier_ for the command, which is then used to build the
hierarchy (each command can have a `children` element where these
identifier are listed).

The command definition is a hash with the following shape:

    name: foo
    help: foo the bar
    description: foo allows us to foo the bar
    supports: ['foo', 'Foo']
    options:
      - name: whip
        getopt: 'whip|w=s'
        environment: FOO_WHIP
        default: gargle
    execute: «executable»
    children: ['foo.bar', 'baz']
    leaf: 0
    allow-residual-options: 0
    collect:  «executable»
    merge: «merge»
    validate: ... «executable» or data structure...
    sources: ['+CmdLine', '+Environment', '+Parent', '+Default']
    default-child: 'foo.bar'
    no-auto: 1
    commit: «executable»

The following keys are supported:

- `name`
- `help`
- `description`

    These do what they advertise, and are used when building the help for
    the command automatically.

- `supports`

    This indicates all the different variants of the command that are
    allowed, i.e. the actual strings that trigger the selection of this
    command while looking for a suitable candidate;

- `options`

    This is a list of options, each with metadata useful to gather values
    for the option. The actual content is dependent of what sources are then
    used. The `name` sub-field is used in the automatic help generation;
    other sub-options are self-explanatory (`getopt`, `environment`, and
    `default`).

- `execute`

    This is the callback that is called when the command is selected for
    execution.

- `children`

    This is a list of children, i.e. allowed sub-commands, specified by
    their identifier in the `commands` hash. This list is normally enriched
    with sub-commands `help` and `commands` automatically, unless the
    automatic children have been changed or disabled. It is possible to mark
    a command as a _leaf_ (missing also sub-commands `help`/`commands`)
    by setting this parameter to a false value, otherwise it must be an
    array;

- `leaf`

    This is an alternative, hopefully more readable, way to set the command
    as a _leaf_ and avoid considering any sub-command, including the
    auto-generated ones.

- `allow-residual-options`

    This boolean indicates whether additional options in the command are
    allowed; it is tied to `+CmdLine` and getopt and defaults to false.

    It means that if a command accepts option `--foo` only, calling the
    command with `--foo --bar` will result in an error and `--bar` will
    not be tried as a sub-command.

    Reasons to disable this (by setting this option to true) might be if a
    leaf command will then use the rest of the argument list to e.g. call an
    external program.

- `collect`
- `merge`

    These allow overriding the internal default behaviour of `App::Easer`

- `validate`

    This can be a sub reference called to perform the validation, or a hash
    that, when the default validator is in effect, will be used to call
    `Params::Validate`.

- `commit`

    This optional callback is invoked just after the parsing of the
    configuration and its optional validation. It shouldn't be normally
    needed, but it allows a "former" command to perform actions before the
    search mechanism investigates further down looking for the target
    command.

- `sources`

    This is the list of sources to gather values for options. It defaults to
    whatever has been set in the top-level `configuration` of the
    application, or `+CmdLine +Environment +Parent +Default` by default.

    It might be helpful to override this setting in the `MAIN` entry point
    command, e.g. to add the loading of a configuration file once and for
    all.

    Items are executables, i.e. sub references or names that will be
    _resolved_ into sub references through the _factory_.

- `default-child`

    When the arguments list is exhausted, this option allows setting the
    _last_ sub-command name. By default it is `help`, but this can be
    overridden. Setting this to a false value disables looking for a
    sub-command, so it allows addressing the command itself directly.

- `no-auto`

    This option disables the automatic addition of automatically generated
    sub-commands.

    If set to an array reference, all items in the array will be filtered
    out from the list of automatically added sub-commands. If set to the
    string `*`, all automatic sub-commands will be ignored.

# FUNCTIONS

The following functions can be optionally imported.

## d

    d(['whatever', {hello => 'world'}]);

Dump data on standard error using [Data::Dumper](https://metacpan.org/pod/Data::Dumper).

## run

    run($application, \@args);

    # hash data structure
    run({...}, \@ARGV);

    # filename or string, in JSON or Perl
    run('/path/to/app.json', \@ARGV);
    run('/path/to/app.pl', \@ARGV);
    run(\$app, \@ARGV);

    # filehandle, data in JSON or Perl
    run(\*DATA, \@ARGV)

Run an application.

Takes two positional parameters:

- an _application_ definition, which can be provided as:
    - hash reference ("native" format)
    - reference to a string, containing either a JSON or a Perl definition for
    the application.

        For the JSON alternative, the string must contain a JSON object so that
        the parsing returns a reference to a hash.

        For the Perl alternative, the text is `eval`ed and must return  a
        reference to a hash.

    - a string with a file path, pointing to either a JSON or a Perl file. The
    file is loaded and treated as described above for the _reference to a
    string_ case;
    - a filehandle, allowing to load either a JSON or a Perl file. The content
    is treated as described above for the _reference to a string_ case.
- the command-line arguments to parse (usually taken from `@ARGV`),
provided as a reference to an array.

# BUGS AND LIMITATIONS

Minimum perl version 5.24.

Report bugs through GitHub (patches welcome) at
[https://github.com/polettix/App-Easer](https://github.com/polettix/App-Easer).

# AUTHOR

Flavio Poletti <flavio@polettix.it>

# COPYRIGHT AND LICENSE

Copyright 2021 by Flavio Poletti <flavio@polettix.it>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
