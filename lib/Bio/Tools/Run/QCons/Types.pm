package Bio::Tools::Run::QCons::Types;

# ABSTRACT: Type library for Bio::Tools::Run::QCons

use strict;
use warnings;

use Mouse::Util::TypeConstraints;
use namespace::autoclean;

use IPC::Cmd qw(can_run);

subtype 'Executable'
    => as 'Str',
    => where { _exists_executable($_) },
    => message { "Can't find $_ in your PATH or not an executable" };

sub _exists_executable {
    my $candidate = shift;

    return 1 if -x $candidate;

    return scalar can_run($candidate);
}

no Mouse::Util::TypeConstraints;
