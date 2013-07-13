use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'WebService::Dofus',
    AUTHOR           => q/"Jeff Ober" <"jeffober@gmail.com">/,
    VERSION_FROM     => 'lib/WebService/Dofus.pm',
    ABSTRACT_FROM    => 'lib/WebService/Dofus.pm',
    LICENSE          => 'BSD',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Moose'                     => 0,
        'MooseX::StrictConstructor' => 0,
        'namespace::autoclean'      => 0,
        'Const::Fast'               => 0,
        'HTTP::Cookies'             => 0,
        'HTTP::Request::Common'     => 0,
        'JSON'                      => 0,
        'LWP::UserAgent'            => 0,
        'Mojo::DOM'                 => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'WebService-Dofus-*' },
);
