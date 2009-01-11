package Bio::Tools::Run::Qcons;

use Moose;
extends 'Bio::Tools::Run::WrapperBase', 'Moose::Object';

# Como el constructor no está en este módulo, tengo que setear
# los parámetros a 'lazy' para que escriba el valor Default.

has 'program_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Qcontacts',
    lazy    => 1,
);

has 'program_dir' => (
    is  => 'rw',
    isa => 'Str',
);

has 'chains' => (
    is         => 'rw',
    isa        => 'ArrayRef',
    auto_deref => 1,
    lazy       => 1,
    default    => sub { [ '', '' ] },
);

has 'probe_radius' => (
    is      => 'rw',
    isa     => 'Num',
    default => 1.4,
    lazy    => 1,
);

has 'arguments' => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy       => 1,
    auto_deref => 1,
    builder    => '_set_arguments',
);

has file => (
    is  => 'rw',
    isa => 'Str',
);

override 'run' => sub {

    # Run Qcontacts with the set parameters, and return
    # an array with the contact information.

    my $self = shift;
    my $arguments;
    my $executable = $self->executable;
    my $tempdir    = $self->tempdir . '/';
    $self->arguments->{-prefOut} = $tempdir;
    map { $arguments .= "$_ " } $self->arguments;

    qx{ $executable $arguments };

    my @contacts_by_atom    = $self->_parse_by_atom;
    my @contacts_by_residue = $self->_parse_by_residue;
    return \@contacts_by_atom, \@contacts_by_residue;
    $self->cleanup;
};

sub _parse_by_residue {

    # Qcontacts outputs two files. This subroutine parses
    # the file that outputs residue-residue contacts.

    my $self = shift;
    my @contacts;
    my $io = $self->io;

    # Get the path to the output file.
    my $filename = $self->arguments->{-prefOut} . '-by-res.vor';

    # Initialize a Bio::Root::IO object to read the output file.
    $io->_initialize_io( -file => $filename );

    # Parse the file line by line, each line corresponds to a
    # contact.
    while ( my $line = $io->_readline ) {
        my @fields = split( /\s+/, $line );

        my %contact = (
            res1 => {
                number => $fields[1],
                name   => $fields[2],
            },
            res2 => {
                number => $fields[5],
                name   => $fields[6],
            },
            area => $fields[8],
        );
        push @contacts, \%contact;
    }

    return @contacts;
}

sub _parse_by_atom {

    # Qcontacts outputs two files. This subroutine parses
    # the file that outputs atom-atom contacts.

    my $self = shift;
    my @contacts;
    my $io = $self->io;

    # Get the path to the output file.
    my $filename = $self->arguments->{-prefOut} . '-by-atom.vor';

    # Initialize a Bio::Root::IO object to read the output file.
    $io->_initialize_io( -file => $filename );

    # Parse the file line by line, each line corresponds to a
    # contact.

    my %meaning_for = (

        # What each parsed field means, depending on the contact
        # type (fields[1])

        # contact type  => {  field number => meaning      }
        V => { 13 => 'area' },
        H => { 13 => 'area', 14 => 'angle', 15 => 'Rno' },
        S => {
            13 => 'area',
            15 => 'dGhb',
            17 => 'dGip',
            18 => 'angle',
            19 => 'Rno'
        },
        I => { 13 => 'area', 14 => 'Rno' },
    );

    while ( my $line = $io->_readline ) {
        my @fields = split( ' ', $line );
        my %contact = (
            atom1 => {
                number     => $fields[5],
                name       => $fields[6],
                res_name   => $fields[3],
                res_number => $fields[2],
            },
            atom2 => {
                number     => $fields[11],
                name       => $fields[12],
                res_name   => $fields[9],
                res_number => $fields[8],
            },
            type => $fields[1],
            area => $fields[8],
        );

        # I can't wait for Perl 6's junctions.
        foreach my $type ( keys %meaning_for ) {
            if ( $type eq $fields[1] ) {
                foreach my $field ( keys %{ $meaning_for{$type} } ) {

                    # I just realized that there's parameter in the 'S' type
                    # that has a ')' sticked to it, remove it.
                    $fields[$field] =~ s/\)//g;
                    $contact{ $meaning_for{$type}->{$field} }
                        = $fields[$field];
                }    # <--|
            }    # <------| I don't like how this looks!
        }    # <----------| I don't like nested foreach loops!

        push @contacts, \%contact;
    }

    return @contacts;

}

sub _set_arguments {
    my $self = shift;
    return {
        -c1 => ${ $self->chains }[0],
        -c2 => ${ $self->chains }[1],
        -i  => $self->file,

        #-prefOut => $self->tempdir . '/',
        -probe => $self->probe_radius,
    };
}

no Moose;
1
