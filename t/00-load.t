#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Bio::Tools::Run::QCons' );
}

diag( "Testing Bio::Tools::Run::QCons $Bio::Tools::Run::QCons::VERSION, Perl $], $^X" );
