#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Bio::Tools::Run::Qcons' );
}

diag( "Testing Bio::Tools::Run::Qcons $Bio::Tools::Run::Qcons::VERSION, Perl $], $^X" );
