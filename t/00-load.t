#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WebService::Dofus' ) || print "Bail out!\n";
}

diag( "Testing WebService::Dofus $WebService::Dofus::VERSION, Perl $], $^X" );
