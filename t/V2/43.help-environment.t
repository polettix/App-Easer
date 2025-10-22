#!/usr/bin/env perl
use v5.24;
use experimental 'signatures';
use Test::More;
use File::Basename 'dirname';
use lib dirname(__FILE__);
use LocalTester;

my $app = {
   environment_prefix => 'TOP_',
   options => [
      {
         getopt      => 'foo',
         environment => 1,
         transmit    => 1,
      }
   ],
   children => [
      {
         name => 'bar',
         environment_prefix => 'MID_',
         options => [
            '+parent',
            {
               getopt => 'bar',
               environment => 1,
            }
         ],
      },
      {
         name => 'baz',
         options => [
            '+parent',
            {
               getopt => 'baz-galook',
               environment => 1,
            }
         ],
      },
   ]
};

subtest 'help me to help' => sub {
   test_run($app, [qw< help >], {}, undef)
     ->no_exceptions->stdout_like(qr{environment: TOP_FOO},
         q{environment variable name})
     ->stderr_like(qr{\A\s*\z}, 'no complaints on standard error');
   test_run($app, [qw< help bar >], {}, undef)
     ->no_exceptions->stdout_like(qr{(?mxs: environment:\s+TOP_FOO.*environment:\s+TOP_MID_BAR)},
         q{environment variable name})
     ->stderr_like(qr{\A\s*\z}, 'no complaints on standard error');
   test_run($app, [qw< help baz >], {}, undef)
     ->no_exceptions->stdout_like(qr{(?mxs: environment:\s+TOP_FOO.*environment:\s+TOP_BAZ_GALOOK)},
         q{environment variable name})
     ->stderr_like(qr{\A\s*\z}, 'no complaints on standard error');
};

done_testing();
