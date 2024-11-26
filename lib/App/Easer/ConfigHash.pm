package App::Easer::ConfigHash;
use v5.24;
use warnings;
use experimental qw< signatures >;
use Storable ();

sub new ($package, $hash, $opts = {}) {
   my $self = bless { clone => ($opts->{clone} // 0) }, $package;
   return $self->set_config_hash($hash);
}

sub config ($self, @keys) {
   return unless @keys;
   my $hash = $self->{hash};
   return $hash->{$keys[0]} if @keys == 1;
   return $hash->@{@keys};
}

sub config_hash ($self) {
   my $hash = $self->{hash};
   $hash = Storable::dclone($hash) if $self->{clone};
   return $hash;
}

sub set_config ($self, $key, @value) {
   my $hash = $self->{hash};
   delete($hash->{$key});
   $hash->{$key} = $value[0] if @value;
   return $self;
}

sub set_config_hash ($self, $hash) {
   $hash = Storable::dclone($hash) if $self->{clone};
   $self->{hash} = $hash;
   return $self;
}

1;
