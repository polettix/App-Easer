---
# Feel free to add content and custom Front Matter to this file.
# To modify the layout, see https://jekyllrb.com/docs/themes/#overriding-theme-defaults

title: 'App::Easer Tutorials'
layout: default
---

# Getting started

Let's get started with [App::Easer][].

## Installation

[App::Easer][] is a regular [Perl][] module; here are a few hints for
[Installing Perl Modules][] in case of need.

Anyway, the goal of [App::Easer][] is to be confined into a single
[Perl][] file that can be easily embedded into an application, in case of
need. Think [App::FatPacker][]. For this reason, nothing prevents people
from getting the module's file directly, e.g. the very latest (and
possibly buggy, use at your own risk!) version in GitHub [here][latest].

After making sure the module's file (contents) can be "seen" by your
program, it suffices to `use` it. The suggestion is to import *at least*
the `run` function, although the `d` (*dump on standard error*) function
can come handy for debugging too.

```perl
use App::Easer qw< run d >;
```

Done! We're ready to move on.

## A basic template

This basic template can get us started:

```perl
#!/usr/bin/env perl
use v5.24;
use warnings;
use experimental 'signatures';
no warnings 'experimental::signatures';
use App::Easer qw< run d >;

my $APPNAME = 'galook';

my $application = {
   factory       => {prefixes => {'#' => 'MyApp#'}},
   configuration => {

      # the name of the application, set it above in $APPNAME
      name               => $APPNAME,

      # figure out names of environment variables automatically
      'auto-environment' => 1,

      # allow for configuration files
      sources            => '+SourcesWithFiles',
      # sources => '+DefaultSources',

      # sub-commands without children are leaves (no sub help/commands)
      # 'auto-leaves'    => 1,

      # help goes to standard error by default, override to stdout
      # 'help-on-stderr' => 0,

      # Where to get the specifications for commands
      # specfetch => '+SpecFromHash',         # default
      # specfetch => '+SpecFromHashOrModule', # possible alternative
   },
   commands => {
      MAIN => {
         help        => 'An application to do X',
         description => 'An application to do X, easily',
         options     => [
            {
               getopt      => 'config|c=s',
               help        => 'path to the configuration file',
               environment => 1,
               # default     => "$ENV{HOME}/.$APPNAME.json",
               # required    => 1,
            },
         ],
         sources        => '+SourcesWithFiles',
         # 'config-files' => ["/etc/$APPNAME.json"],
         children => [qw< foo bar >],
      },
      foo => {
         help        => 'An example sub-command',
         description => 'An example sub-command, more details',
         options     => [
            {
               getopt      => 'baz|b=s',
               help        => '',
               environment => 1,
               # default     => '',
               # required    => 1,
            },
         ],
         execute => '#foo',
      },
      bar => {
         help        => 'Another example sub-command',
         description => 'Another example sub-command, more details',
         options     => [
            {
               getopt      => 'galook|g=s',
               help        => '',
               environment => 1,
               # default     => '',
               # required    => 1,
            },
         ],
         execute => '#bar',
      },
   }
};
exit run($application, [@ARGV]);

package MyApp;

# implementation of sub-command foo
sub foo ($general, $config, $args) {
    # $general is a hash reference to the overall application
    # $config  is a hash reference with options
    # $args    is an array reference with "residual" cmd line arguments
    for my $key (sort { $a cmp $b } keys $config->%*) {
        say "$key: $config->{$key}";
    }
    say "($args->@*)";
    return;
}

# implementation of sub-command bar
sub bar ($general, $config, $args) {
    say defined($config->{galook}) ? $config->{galook} : '*undef*';
    return;
}
```

[App::Easer]: https://metacpan.org/pod/App::Easer
[Installing Perl Modules]: https://github.polettix.it/ETOOBUSY/2020/01/04/installing-perl-modules/
[Perl]: https://www.perl.org/
[App::FatPacker]: https://metacpan.org/pod/App::FatPacker
[latest]: https://raw.githubusercontent.com/polettix/App-Easer/main/lib/App/Easer.pm
