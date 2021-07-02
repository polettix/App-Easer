#!/usr/bin/env perl
use strict;
use warnings;
use Template::Perlish ();
use Path::Tiny;

my ($distro, $version, $dname) = @ARGV;
my @parts = split /-/, $dname;
$parts[-1] .= '.pod';
my $podfile = path($distro)->child('lib', @parts);
my $readme = path($distro)->child('README');

my $tp = Template::Perlish->new(
   start     => '{{[',
   stop      => ']}}',
   variables => {
      distro  => $distro,
      version => $version,
   },
);

for my $file ($podfile, $readme) {
   my $rendered = $tp->process($file->slurp_raw());
   $file->spew_raw($rendered);
}
