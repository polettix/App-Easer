use v5.24;
use experimental 'signatures';
use Test::More;
use Scalar::Util qw< refaddr >;

use App::Easer::ConfigHash;

subtest no_clone => sub {
   my $hash = { foo => 'bar', baz => 'galook' };
   my $cp = App::Easer::ConfigHash->new($hash);
   isa_ok $cp, 'App::Easer::ConfigHash';
   can_ok $cp, qw< config config_hash new set_config set_config_hash >;

   is refaddr($hash), refaddr($cp->config_hash),
      'default return same hash reference wrt input';
   is $cp->config('foo'), $hash->{foo}, 'getting single value';

   is_deeply [ $cp->config(qw< baz foo >) ],
      [ $hash->@{qw< baz foo >} ], 'getting multiple values';

   $cp->set_config(what => 'ever');
   $cp->set_config('foo'); # deletes it
   is_deeply $cp->config_hash, { what => 'ever', baz => 'galook' },
      'set_config changed configuration as expected';
   is_deeply $hash, { what => 'ever', baz => 'galook' },
      'side-effect on original hash reference';
};

subtest clone => sub {
   my $hash = { foo => 'bar', baz => 'galook' };
   my $cp = App::Easer::ConfigHash->new($hash, {clone => 1});
   isa_ok $cp, 'App::Easer::ConfigHash';
   can_ok $cp, qw< config config_hash new set_config set_config_hash >;

   isnt refaddr($hash), refaddr($cp->config_hash),
      'return different hash reference wrt input';
   isnt refaddr($cp->config_hash), refaddr($cp->config_hash),
      'return different hash at every call to config_hash';

   is $cp->config('foo'), $hash->{foo}, 'getting single value';

   is_deeply [ $cp->config(qw< baz foo >) ],
      [ $hash->@{qw< baz foo >} ], 'getting multiple values';

   $cp->set_config(what => 'ever');
   $cp->set_config('foo'); # deletes it
   is_deeply $cp->config_hash, { what => 'ever', baz => 'galook' },
      'set_config changed configuration as expected';
   is_deeply $hash, { foo => 'bar', baz => 'galook' },
      'no side-effect on original hash reference';
};

done_testing();
