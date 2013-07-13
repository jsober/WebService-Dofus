#-------------------------------------------------------------------------------
#
#-------------------------------------------------------------------------------
package WebService::Dofus::Spell;

use strict;
use warnings;
use Carp;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

use Const::Fast           qw/const/;
use Fcntl                 qw/:flock/;
use File::Path            qw//;
use File::Spec            qw//;
use HTTP::Cookies         qw//;
use HTTP::Request::Common qw/POST/;
use JSON                  qw//;
use LWP::UserAgent        qw//;
use Mojo::DOM             qw//;

const our $HOST => 'http://www.dofus.com';
const our $PATH => '/requests/encyclopedia_spell';

# Maps English class names to French
const our %EN_TO_FR => (
    foggernaut   => 'steamer',
    cra          => 'cra',
    enutrof      => 'enutrof',
    feca         => 'feca',
    iop          => 'iop',
    osamodas     => 'osamodas',
    sram         => 'sram',
    sacrier      => 'sacrieur',
    ecaflip      => 'ecaflip',
    eniripsa     => 'eniripsa',
    sadida       => 'sadida',
    xelor        => 'xelor',
    pandawa      => 'pandawa',
    rogue        => 'roublard',
    masqueraider => 'zobal',
);

const our %FR_CLASSES => map { $_ => 1 } values %EN_TO_FR;
const our %EN_CLASSES => map { $_ => 1 } keys   %EN_TO_FR;
const our $NUM_SPELLS => 21;
const our $MAX_LEVEL  => 6;

my %_valid;
@_valid{keys %FR_CLASSES, keys %EN_CLASSES} = (1) x scalar(keys %FR_CLASSES, keys %EN_CLASSES);
const our @VALID => keys %_valid;
undef %_valid;

has 'cache_dir' => (
    isa      => 'Str',
    is       => 'rw',
    required => 1,
);

sub _data_key { join '-', @_ }

sub _cache_file {
    my ($self, $class, $spell, $level) = @_;
    my $path = File::Spec->catfile($self->cache_dir, $class, $spell, $level);

    if (-e $path && !-d $path) {
        File::Path::rmtree($path);
    }

    unless (-e $path) {
        File::Path::mkpath($path);
    }

    return File::Spec->catfile($path, 'data');
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

sub _retrieve {
    my ($self, $class, $spell, $level) = @_;
    my $referer = sprintf 'http://www.dofus.com/en/mmorpg-game/characters/%s', $class;

    # Determine parameter value for class name. The subroutine parameter
    # accepts either EN or FR names.
    if (exists $EN_CLASSES{$class}) {
        $class = $EN_TO_FR{$class};
    } elsif (!exists $FR_CLASSES{$class}) {
        croak "Unrecognized class name '$class'. Use one of [@VALID]";
    }

    if ($spell > $NUM_SPELLS || $spell < 1) {
        croak "Invalid spell $spell. Use a number between 1 and $NUM_SPELLS.";
    }

    if ($level > $MAX_LEVEL || $level < 1) {
        croak "Invalid level. Use a number between 1 and 6."
    }

    unless ($self->_has_cache($class, $spell, $level)) {
        my $param  = [ c => $class, s => $spell, spelllevel => $level ];
        my %header = ('X-Requested-With' => 'XMLHttpRequest');

        my $ua = LWP::UserAgent->new('Test/1.0');
        $ua->env_proxy;
        #$ua->show_progress(1);
        $ua->cookie_jar(HTTP::Cookies->new());

        my $request  = POST($HOST . $PATH, %header, Content => $param);
        my $response = $ua->request($request);

        if ($response->is_success) {
            my $json    = $response->content;
            my $decoded = JSON::decode_json($json);
            $self->_set_cache($class, $spell, $level, $decoded->[0]);
        } else {
            croak sprintf('Error %d: %s', $response->code, $response->message);
        }
    }

    return $self->_get_cache($class, $spell, $level);
}

sub info {
    my ($self, $class, $spell, $level) = @_;
    my $html = $self->_retrieve($class, $spell, $level);
    my $dom  = Mojo::DOM->new($html);

    my $details = {};
    $dom->find('div.autres li')->each(sub {
        my $e   = shift;
        my $key = $e->text;
        my $val = $e->at('span')->text;
        $details->{$key} = $val;
    });

    my ($ra, $ap);
    my $ra_ap_span = $dom->at('div.title')->children('span')->[-1];
    unless (($ra, $ap) = ($ra_ap_span =~ /\s*(\d+ - \d+)\s*RA \/ (\d+) AP/)) {
        ($ap) = ($ra_ap_span =~ /\s*(\d+) AP/);
        $ra = 0;
    }

    my @effects;
    my @critical;
    $dom->find('div.effets')->each(sub {
        my $e = shift;
        $e->find('span.normaux li'  )->each(sub { push @effects,  shift->text });
        $e->find('span.critiques li')->each(sub { push @critical, shift->text });
    });

    # The first LIs are labels
    shift @effects;
    shift @critical;

    my %data = (
        name        => $dom->at('div.title h3')->all_text,
        level       => $level,
        graphic     => $dom->at('span.picto img')->{src},
        description => $dom->at('div.description')->children('span')->reverse->first->all_text,
        ap          => $ap,
        ra          => $ra,
        details     => $details,
        effects     => \@effects,
        critical    => \@critical,
    );

    return %data;
}

1;