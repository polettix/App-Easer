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
    use App::Easer V2 => 'run';
    my $app = {
       aliases     => ['foo'],
       help        => 'this is the main app',
       description => 'Yes, this really is the main app',
       options     => [
          {
             name        => 'foo',
             help        => 'option foo!',
             getopt      => 'foo|f=s',
             environment => 'FOO',
             default     => 'bar',
          },
       ],
       execute => sub ($instance) {
          my $foo = $instance->config('foo');
          say "Hello, $foo!";
          return 0;
       },
       default_child => '-self',    # run execute by default
       children => [
          {
             aliases => ['bar'],
             help => 'this is a sub-command',
             description => 'Yes, this is a sub-command',
             execute => sub { 'Peace!' },
          },
       ],
    };
    exit run($app, $0, @ARGV);

# DESCRIPTION

**NOTE**: this software should be considered "late alpha" maturity. I'm
mostly happy with the interface, but there are still a few things that
might get changed. _Anyway_, if you find a release of `App::Easer` to
work fine for you, it's fair to assume that you will not need to get a
newer one later.

App::Easer provides the scaffolding for implementing hierarchical
command-line applications in a very fast way.

Development today happens only in [App::Easer::V2](https://metacpan.org/pod/App%3A%3AEaser%3A%3AV2). The legacy
interface is still available in [App::Easer::V1](https://metacpan.org/pod/App%3A%3AEaser%3A%3AV1), which is also the
default but has its own documentation.

# BUGS AND LIMITATIONS

Minimum perl version 5.24.

Report bugs through GitHub (patches welcome) at
[https://github.com/polettix/App-Easer](https://github.com/polettix/App-Easer).

# AUTHOR

Flavio Poletti <flavio@polettix.it>

# COPYRIGHT AND LICENSE

Copyright 2021, 2022 by Flavio Poletti <flavio@polettix.it>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Just to be clear: apache-2.0
