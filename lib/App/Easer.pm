package App::Easer;
use v5.24;
use warnings;
use experimental qw< signatures >;
no warnings qw< experimental::signatures >;
{ our $VERSION = '0.001' }

use Exporter 'import';
our @EXPORT_OK = qw< d run >;

sub add_auto_commands ($application) {
   my $commands = $application->{commands};
   $commands->{help} //= {
      name => 'help',
      supports => ['help'],
      help => 'print a help message',
      description => 'print help for (sub)command',
      'allow-residual-options' => 0,
      'no-auto' => '*',
      execute => \&stock_help,
   };
   $commands->{commands} //= {
      name => 'commands',
      supports => ['commands'],
      help => 'list sub-commands',
      description => 'Print list of supported sub-commands',
      'allow-residual-options' => 0,
      children => undef,
      execute => \&stock_commands,
   };
   return $application;
}

sub collect ($self, $spec, $args) {
   my @sequence;
   my $config = {};
   my @residual_args;

   my $merger = $spec->{merge}
     // $self->{application}{configuration}{merge} // \&hash_merge;
   $merger = $self->{factory}->($merger, 'merge');    # "resolve"

   my $sources = $spec->{sources}
     // $self->{application}{configuration}{sources}
     // [qw< +CmdLine +Environment +Parent +Default >];
   for my $source_spec ($sources->@*) {
      my ($src, $src_cnf) =
        'ARRAY' eq ref $source_spec
        ? $source_spec->@*
        : ($source_spec, {});
      $src = $self->{factory}->($src, 'collect');    # "resolve"
      $src_cnf = {$spec->%*, $src_cnf->%*, config => $config};
      my ($slice, $residual_args) = $src->($self, $src_cnf, $args);
      push @residual_args, $residual_args->@* if defined $residual_args;
      push @sequence, $slice;
      $config = $merger->(@sequence);
   } ## end for my $source_spec ($sources...)

   return ($config, \@residual_args);
} ## end sub collect

sub collect_options ($self, $spec, $args) {
   my $factory = $self->{factory};
   my $collect = $spec->{collect}
     // $self->{application}{configuration}{collect} // \&collect;
   my $collector = $factory->($collect, 'collect');    # "resolve"
   (my $config, $args) = $collector->($self, $spec, $args);
   push $self->{configs}->@*, $config;
   return $args;
} ## end sub collect_options

sub commandline_help ($getopt) {
   my @retval;

   my ($mode, $type, $desttype, $min, $max, $default);
   if (substr($getopt, -1, 1) eq '!') {
      $type = 'bool';
      substr $getopt, -1, 1, '';
      push @retval, 'boolean option';
   }
   elsif (substr($getopt, -1, 1) eq '+') {
      $mode = 'increment';
      substr $getopt, -1, 1, '';
      push @retval, 'incremental option (adds 1 every time it is provided)';
   }
   elsif ($getopt =~ s<(
         [:=])    # 1 mode
         ([siof]) # 2 type
         ([@%])?  # 3 desttype
         (?:
            \{
               (\d*)? # 4 min
               ,?
               (\d*)? # 5 max
            \}
         )? \z><>mxs) {
      $mode = $1 eq '=' ? 'mandatory' : 'optional';
      $type = $2;
      $desttype = $3;
      $min = $4;
      $max = $5;
      if (defined $min) {
         $mode = $min ? 'optional' : 'required';
      }
      $type = {
         s => 'string',
         i => 'integer',
         o => 'perl-extended-integer',
         f => 'float',
      }->{$type};
      my $line = "$mode $type option";
      $line .= ", at least $min times" if defined($min) && $min > 1;
      $line .= ", no more than $max times" if defined($max) && length($max);
      $line .= ", list valued" if defined($desttype) && $desttype eq '@';
      push @retval, $line;
   }
   elsif ($getopt =~ s<: (\d+) ([@%])? \z><>mxs) {
      $mode = 'optional';
      $type = 'i';
      $default = $1;
      $desttype = $2;
      my $line = "optional integer, defaults to $default";
      $line .= ", list valued" if defined($desttype) && $desttype eq '@';
      push @retval, $line;
   }
   elsif ($getopt =~ s<:+ ([@%])? \z><>mxs) {
      $mode = 'optional';
      $type = 'i';
      $default = 'increment';
      $desttype = $1;
      my $line = "optional integer, current value incremented if omitted";
      $line .= ", list valued" if defined($desttype) && $desttype eq '@';
      push @retval, $line;
   }

   my @alternatives = split /\|/, $getopt;
   if ($type eq 'bool') {
      push @retval, map {
         if (length($_) eq 1) { "-$_" }
         else { "--$_ | --no-$_" }
      } @alternatives;
   }
   elsif ($mode eq 'optional') {
      push @retval, map {
         if (length($_) eq 1) { "-$_ [<value>]" }
         else { "--$_ [<value>]" }
      } @alternatives;
   }
   else {
      push @retval, map {
         if (length($_) eq 1) { "-$_ <value>" }
         else { "--$_ <value>" }
      } @alternatives;
   }

   return @retval;
}

sub commit_configuration ($self, $spec, $args) {
   my $commit = $spec->{commit} // return;
   $self->{factory}->($commit, 'commit')->($self, $spec, $args);
}

sub d (@stuff) {
   no warnings;
   require Data::Dumper;
   local $Data::Dumper::Indent = 1;
   warn Data::Dumper::Dumper(@stuff % 2 ? \@stuff : {@stuff});
}

sub default_getopt_config ($has_children) {
   my @r = qw< gnu_getopt >;
   push @r, qw< require_order pass_through > if $has_children;
   return \@r;
}

sub execute ($self, $args) {
   my $command = $self->{trail}[-1][0];
   my $executable = $self->{application}{commands}{$command}{execute}
      or die "no executable for '$command'\n";
   $executable = $self->{factory}->($executable, 'execute'); # "resolve"
   my $config = $self->{configs}[-1] // {};
   return $executable->($self, $config, $args);
}

sub factory ($executable, $default_subname = '', $opts = {}) {
   return $executable if 'CODE' eq ref $executable;    # easy
   state $factory = sub ($executable, $default_subname) {
      return eval $executable if $executable =~ m{\A \s}mxs;
      my @prefixes =
          !defined $opts->{prefixes}       ? ()
        : 'ARRAY' eq ref $opts->{prefixes} ? ($opts->{prefixes}->@*)
        :                                    ($opts->{prefixes});
      push @prefixes, {'+' => 'App::Easer#stock_'};
    SEARCH:
      for my $expansion_for (@prefixes) {
         for my $p (keys $expansion_for->%*) {
            next if $p ne substr $executable, 0, length $p;
            substr $executable, 0, length $p, $expansion_for->{$p};
            last SEARCH;
         }
      } ## end SEARCH: for my $expansion_for (...)
      my ($package, $sname) = split m{\#}mxs, $executable;
      $sname = $default_subname unless defined $sname && length $sname;
      if (my $s = $package->can($sname)) { return $s }
      (my $path = "$package.pm") =~ s{::}{/}gmxs;
      require $path;
      if (my $s = $package->can($sname)) { return $s }
      die "no '$sname' in '$package'\n";
   };
   state $cache = {};
   return $cache->{$executable . ' ' . $default_subname} //=
     $factory->($executable, $default_subname);
} ## end sub factory

sub fetch_subcommand ($self, $spec, $args) {
   my @children = get_children($self, $spec) or return;
   my ($candidate, $candidate_from_args);
   if ($args->@*) {
      $candidate = $args->[0];
      $candidate_from_args = 1;
   }
   elsif (exists $spec->{'default-child'}) {
      $candidate = $spec->{'default-child'};
      return unless defined $candidate && length $candidate;
   }
   elsif (exists $self->{application}{configuration}{'default-child'}) {
      $candidate = $self->{application}{configuration}{'default-child'};
   }
   else {
      $candidate = 'help';
   }
   if (my $child = get_child($self, $spec, $candidate)) {
      shift $args->@* if $candidate_from_args;
      return ($child, $candidate);
   }
   my @names = map { $_->[1] } $self->{trail}->@*;
   shift @names; # remove first one
   my $path = join '/', @names, $candidate;
   die "cannot find sub-command '$path'\n";
}

sub generate_factory ($c) {
   my $wrapped = \&factory;    # use our stock factory by default
   $wrapped = factory($c->{create}, 'factory', $c) if defined $c->{create};
   return sub ($e, $d = '') { $wrapped->($e, $d, $c) };
}

sub get_child ($self, $spec, $name) {
   for my $child (get_children($self, $spec)) {
      my $command = $self->{application}{commands}{$child};
      next unless grep { $_ eq $name } $command->{supports}->@*;
      return $child;
   }
   return;
}

sub get_children ($self, $spec) {
   return if exists($spec->{children}) && ! $spec->{children};
   my @auto = exists $self->{application}{configuration}{'auto-children'}
      ? (($self->{application}{configuration}{'auto-children'} // [])->@*)
      : (qw< help commands >);
   if (exists $spec->{'no-auto'}) {
      if (ref $spec->{'no-auto'}) {
         my %no = map {$_ => 1} $spec->{'no-auto'}->@*;
         @auto = grep {! $no{$_}} @auto;
      }
      elsif ($spec->{'no-auto'} eq '*') {
         @auto = ();
      }
      else {
         die "invalid no-auto, array or '*' are allowed\n";
      }
   }
   return (($spec->{children} // [])->@*, @auto);
}

sub get_descendant ($self, $start, $list) {
   my $target = $start;
   my $cmds = $self->{application}{commands};
   my $path;
   for my $desc ($list->@*) {
      $path = defined($path) ? "$path/$desc" : $desc;
      my $command = $cmds->{$target}
         or die "cannot find sub-command '$path'\n";
      defined($target = get_child($self, $command, $desc))
         or die "cannot find sub-command '$path'\n";
   }

   # check that this last is associated to a real command
   $cmds->{$target} or die "cannot find sub-command '$path'\n";

   return $target;
}

sub hash_merge { return {map { $_->%* } reverse @_} }

sub list_commands ($self, $children) {
   my $retval = '';
   open my $fh, '>', \$retval;
   for my $child ($children->@*) {
      my $command = $self->{application}{commands}{$child};
      my $help = $command->{help};
      my @aliases = ($command->{supports} // [])->@*;
      next unless @aliases;
      printf {$fh} "%15s: %s\n", shift(@aliases), $help;
      printf {$fh} "%15s  (also as: %s)\n", '', join ', ', @aliases
         if @aliases;
   }
   close $fh;
   return $retval;
}

sub load_application ($application) {
   return $application if 'HASH' eq ref $application;

   my $text;
   if ('SCALAR' eq ref $application) {
      $text = $$application;
   }
   else {
      my $fh =
      'GLOB' eq ref $application
      ? $application
      : do {
         open my $fh, '<:encoding(UTF-8)', $application
            or die "cannot open '$application'\n";
         $fh;
      };
      local $/;    # slurp mode
      $text = <$fh>;
      close $fh;
   }

   return eval {
      require JSON::PP;
      JSON::PP::decode_json($text);
   } // eval {
      eval $text;
   } // die "cannot load application\n";
} ## end sub load_application ($application)

sub name_for_option ($o) {
   return $o->{name} if defined $o->{name};
   return $1 if defined $o->{getopt} && $o->{getopt} =~ m{\A(\w+)}mxs;
   return lc $o->{environment} if defined $o->{environment};
   return '~~~';
}

sub params_validate ($self, $spec, $args) {
   my $validator = $spec->{validate} // $self->{application}{configuration}{validate} // return;
   require Params::Validate;
   Params::Validate::validate($self->{configs}[-1]->%*, $validator);
}

sub run ($application, $args) {
   $application = add_auto_commands(load_application($application));
   my $self = {
      application => $application,
      factory     => generate_factory($application->{factory} // {}),
      trail       => [['MAIN', $application->{commands}{MAIN}{name}]],
      configs     => []
   };

   while ('necessary') {
      my $command = $self->{trail}[-1][0];
      my $spec    = $application->{commands}{$command}
        or die "no definition for '$command'\n";

      $args = collect_options($self, $spec, $args);
      validate_configuration($self, $spec, $args);
      commit_configuration($self, $spec, $args);

      my ($subc, $alias) = fetch_subcommand($self, $spec, $args) or last;
      push $self->{trail}->@*, [$subc, $alias];
   } ## end while ('necessary')

   return execute($self, $args) // 0;
} ## end sub run

sub stock_CmdLine ($self, $spec, $args) {
   my @args = $args->@*;
   my $goc = $spec->{getopt_config}
      // default_getopt_config(scalar(($spec->{children} // [])->@*));
   require Getopt::Long;
   Getopt::Long::Configure('default', $goc->@*);

   my %option_for;
   my @specs = map {
         my $go = $_->{getopt};
         ref($go) eq 'ARRAY'
         ? ( $go->[0] => sub { $go->[1]->(\%option_for, @_) } )
         : $go;
      }
      grep { exists $_->{getopt} }
      ($spec->{options} // [])->@*;
   Getopt::Long::GetOptionsFromArray(\@args, \%option_for, @specs)
      or die "bailing out\n";

   # Check if we want to forbid the residual @args to start with a '-'
   my $strict = ! $spec->{'allow-residual-optionss'};
   if ($strict && @args && $args[0] =~ m{\A -}mxs) {
      Getopt::Long::Configure('default', 'gnu_getopt');
      Getopt::Long::GetOptionsFromArray(\@args, {});
      die "bailing out\n";
   }

   return (\%option_for, \@args);
}

sub stock_Default ($self, $spec, @ignore) {
   return {
      map { name_for_option($_) => $_->{default} }
      grep { exists $_->{default} }
      ($spec->{options} // [])->@*
   };
}
sub stock_Environment ($self, $spec, @ignore) {
   return {
      map { $_->{name} => $ENV{$_->{environment}} }
      grep {
         exists($_->{environment}) && exists($ENV{$_->{environment}})
      }
      ($spec->{options} // [])->@*
   };
}

sub stock_Parent ($self, $spec, @ignore) { $self->{configs}[-1] // {} }

sub stock_commands ($self, $config, $args) {
   die "this command does not support arguments\n" if $args->@*;
   my $target = get_descendant($self, $self->{trail}[-2][0], $args);
   my $command = $self->{application}{commands}{$target};
   if (my @children = get_children($self, $command)) {
      my $fh = \*STDOUT; # FIXME
      print {$fh} list_commands($self, \@children);
   }
   else {
      warn "no sub-commands\n";
   }
   return 0;
}

sub stock_help ($self, $config, $args) {
   my $target = get_descendant($self, $self->{trail}[-2][0], $args);
   my $command = $self->{application}{commands}{$target};
   my $fh = \*STDOUT; # FIXME

   print {$fh} $command->{help}, "\n\n";
   
   if (defined (my $description = $command->{description})) {
      $description =~ s{\A\s+|\s+\z}{}gmxs; # trim
      $description =~ s{^}{    }gmxs; # add some indentation
      print {$fh} "Description:\n$description\n\n";
   }

   printf {$fh} "Can be called as: %s\n\n", join ', ',
      $command->{supports}->@* if $command->{supports};

   my $options = $command->{options} // [];
   if ($options->@*) {
      print {$fh} "Options:\n";
      for my $option ($options->@*) {
         printf {$fh} "%15s: %s\n", name_for_option($option), $option->{help} // '';

         if (exists $option->{getopt}) {
            my @lines = commandline_help($option->{getopt});
            printf {$fh} "%15s  command-line: %s\n", '', shift(@lines);
            printf {$fh} "%15s                %s\n", '', $_ for @lines;
         }
         printf {$fh} "%15s  environment : %s\n", '', $option->{environment} // '*undef*'
            if exists $option->{environment};
         printf {$fh} "%15s  default     : %s\n", '', $option->{default} // '*undef*'
            if exists $option->{default};
      }
      print {$fh} "\n";
   }
   else {
      print {$fh} "This command has no options.\n\n";
   }

   if (my @children = get_children($self, $command)) {
      print {$fh} "Sub commands:\n", list_commands($self, \@children), "\n";
   }
   return 0;
}

sub validate_configuration ($self, $spec, $args) {
   my $from_spec = $spec->{validate};
   my $from_self = $self->{application}{configuration}{validate};
   my $validator;
   if (defined $from_spec && 'HASH' ne ref $from_spec) {
      $validator = $self->{factory}->($from_spec, 'validate');
   }
   elsif (defined $from_self && 'HASH' ne ref $from_self) {
      $validator = $self->{factory}->($from_self, 'validate');
   }
   else { # use stock one
      $validator = \&params_validate;
   }
   $validator->($self, $spec, $args);
}

exit run(
   $ENV{APPEASER} // {
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
   },
   [@ARGV]
) unless caller;

1;

=pod

=encoding utf8



=cut
