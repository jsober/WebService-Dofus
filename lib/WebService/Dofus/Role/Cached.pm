package WebService::Dofus::Role::Cached;

use strict;
use warnings;
use Carp;

use Moose::Role;
use namespace::autoclean;

use Fcntl      qw/:flock/;
use File::Path qw//;
use File::Spec qw//;

requires 'cache_group';

has 'cache_dir' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

sub _cache_file {
    my $self = shift;
    my $path = File::Spec->catfile($self->cache_dir, $self->cache_group, @_);
    
    $self->_purge_cache(@_);

    unless (-e $path) {
        File::Path::mkpath($path);
    }

    return File::Spec->catfile($path, 'data');
}

sub _purge_cache {
    my $self = shift;
    my $path = File::Spec->catfile($self->cache_dir, $self->cache_group, @_);
    if (-e $path && !-d $path) {
        File::Path::rmtree($path);
    }
}

sub _has_cache {
    my $self = shift;
    return -e $self->_cache_file(@_);
}

sub _get_cache {
    my $self = shift;
    open my $fh, '<', $self->_cache_file(@_);
    return unless $fh;

    flock $fh, LOCK_SH or croak $!;
    my $data = do { local $/; <$fh> };
    flock $fh, LOCK_UN or croak $!;
    close $fh;

    return $data;
}

sub _set_cache {
    my $self = shift;
    my $data = pop;
    open my $fh, '>', $self->_cache_file(@_) or croak "Error writing to cache: $!";

    flock $fh, LOCK_EX or croak $!;
    print $fh $data;
    flock $fh, LOCK_UN or croak $!;
    close $fh;

    return;
}


no Moose;

1;