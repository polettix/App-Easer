#!/usr/bin/env perl
use strict;
use warnings;
use Template::Perlish ();
use Path::Tiny;

my ($distro, $version, $dname) = @ARGV;

my $distro_dir = path($distro);
my @parts = split /-/, $dname;
my $name = pop(@parts);
my $lib_dir = $distro_dir->child(lib => @parts);

# start with README and the distro's main POD file
my @files = (
   $distro_dir->child('README'),
   $lib_dir->child($name . '.pod'),
);

# go look for additional POD files in the sub-directory, if any
$lib_dir->child($name)->visit(
   sub {
      my $path = shift;
      push @files, $path
         if $path->is_file && $path->basename =~ m{\.pod\z}imxs;
   },
   {recurse => 1},
);

my $tp = Template::Perlish->new(
   binmode   => ':raw',
   start     => '{{[',
   stop      => ']}}',
   variables => {
      distro  => $distro,
      version => $version,
   },
);

for my $file (@files) {
   my $rendered = $tp->process($file->slurp_raw());
   $file->spew_raw($rendered);
}
