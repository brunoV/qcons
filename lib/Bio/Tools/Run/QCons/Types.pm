package Bio::Tools::Run::QCons::Types;
use strict;
use warnings;

use Mouse::Util::TypeConstraints;
use namespace::autoclean;

use File::Which;

subtype 'Executable'
    => as 'Str',
    => where { _exists_executable($_) },
    => message { "Can't find $_ in your PATH or not an executable" };

sub _exists_executable {
    my $candidate = shift;

    return 1 if -x $candidate;

    return scalar which($candidate);
}

no Mouse::Util::TypeConstraints;
