package LocalTester;
use v5.24;
use experimental 'signatures';
use Capture::Tiny 'capture';
use App::Easer V2 => 'run';
use Test::More;
use Exporter 'import';
use Data::Dumper;

our @EXPORT = ('test_run');

sub test_run ($app, $args, $env, $expected_command = 'MAIN') {
   my ($stdout, $stderr, @result, $clean_run, $exception);
   my $self = bless {}, __PACKAGE__;
   local *LocalTester::command_execute = sub ($cmd) {
      my $name = $self->{name} = $cmd->name;
      return unless $name eq ($expected_command // '');
      $self->{conf} = $cmd->config_hash;
      $self->{args} = [$cmd->residual_args];
   };
   eval {
      local @ENV{keys $env->%*};
      while (my ($k, $v) = each $env->%*) {
         if (defined $v) { $ENV{$k} = $v }
         else { delete $ENV{$k} }
      }
      $self->@{qw< stdout stderr result >} = capture {
         scalar run($app, $0, $args->@*)
      };
      1;
   } or do { $self->{exception} = $@ };
   return $self;
} ## end sub test_run

sub stdout_like ($self, $regex, $name = 'stdout') {
   like $self->{stdout} // '', $regex, $name;
   return $self;
}

sub stdout_unlike ($self, $regex, $name = 'stdout') {
   unlike $self->{stdout} // '', $regex, $name;
   return $self;
}

sub diag_stdout ($self) {
   diag $self->{stdout};
   return $self;
}

sub diag_stderr ($self) {
   diag $self->{stderr};
   return $self;
}

sub stderr_like ($self, $regex, $name = 'stderr') {
   like $self->{stderr} // '', $regex, $name;
   return $self;
}

sub conf_is ($self, $expected, $name = 'configuration') {
   is_deeply $self->{conf}, $expected, $name
      or diag Dumper({ got => $self->{conf}, expected => $expected});
   return $self;
}

sub conf_contains ($self, $expected, $name = 'partial configuration') {
   my $got = { map { $_ => $self->{conf}{$_} } keys $expected->%* };
   is_deeply $got, $expected, $name;
   return $self;
}

sub args_are ($self, $expected, $name = 'residual arguments') {
   is_deeply $self->{args}, $expected, $name;
   return $self;
}

sub result_is ($self, $expected, $name = undef) {
   $name //= "result is '$expected'";
   is $self->{result}, $expected, $name;
   return $self;
}

sub no_exceptions ($self, $name = 'no exceptions raised') {
   ok !exists($self->{exception}), $name
      or diag $self->{exception};
   return $self;
}

sub exception_like ($self, $regex, $name = 'exception') {
   like $self->{exception} // '', $regex, $name;
   return $self;
}

1;
