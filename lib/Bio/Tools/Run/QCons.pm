package Bio::Tools::Run::QCons;

use Moose;
extends 'Bio::Tools::Run::WrapperBase', 'Moose::Object';

=head1 NAME

Bio::Tools::Run::Qcons - A wrapper module of the Qcons application
for the analysis of protein-protein contacts.

=head1 SYNOPSIS

   my $q = Bio::Tools::Run::Qcons->new;
   $q->file($pdbfile);
   $q->chains([$chain1, $chain2]);
   my ($contacts_by_atom, $contacts_by_residue) = $q->run;

=head1 DESCRIPTION

This module implements a wrapper for the QCons application. QCons
itself is an implementation of the Polyhedra algorithm for the
prediction of protein-protein contacts. From the program's web page
(L<http://tsailab.tamu.edu/Qcons/>):

"QContacts allows for a fast and accurate analysis of protein binding
interfaces. Given a PDB file to upload your own file (specifying PDB
functionality under construction) and the interacting chains of
interest, QContacts will provide a graphical representation of the
residues in contact. The contact map will not only indicate the
contacts present between the two proteins, but will also indicate
whether the contact is a packing interaction,  hydrogen bond, ion pair
or salt bridge (hydrogen-bonded ion pair). Contact maps allow for easy
visualization and comparison of protein-protein interactions."

For a thorough description of the algorithm, it's limitatinons and a
comparison with several others, refer to Fischer, T. et. al: Assessing
methods for identifying pair-wise atomic contacts across binding
interfaces, J. Struc. Biol., vol 153, p. 103-112, 2006.

=head1 VERSION

Version 0.01

=cut

# Como el constructor no está en este módulo, tengo que setear
# los parámetros a 'lazy' para que escriba el valor Default.

=head1 METHODS

=head2 Constructor

=over 4

=item Bio::Tools::Run::QCons->new();

Create a new QCons object.

=back

=cut

=head2 Methods

=cut

=over 4

=item $q->file($pdbfile);

Gets or sets the file with the protein structures to analyze. The file
format should be PDB.

=cut

has file => (
    is  => 'rw',
    isa => 'Str',
);

=item $q->chains(['A', 'B']);

Gets or sets the chain IDs of the subunits whose contacts the program
will calculate. It takes an array reference of two strings as
argument.

=cut

has chains => (
    is         => 'rw',
    isa        => 'ArrayRef[Str]',
    auto_deref => 1,
    lazy       => 1,
    default    => sub { [ '', '' ] },
);

=item $q->probe_radius($radius);

Gets or sets the probe radius that the program uses to calculate the
exposed and buried surfaces. It defaults to 1.4 Angstroms, and unless
you have a really strong reason to change this, you should refrain
from doing it.

=cut

has probe_radius => (
    is      => 'rw',
    isa     => 'Num',
    default => 1.4,
    lazy    => 1,
);

=item my ($by_atom, $by_res) = $q->run;

Runs the program and parses the result files. Typically, the program
outputs two files, in which the contact information is described in a
per-atom or per-residue basis. The 'run' method will return two array
references with all the information for every contact found.

The structure of the C<@$by_atom> array is as follows:

   $by_atom = [
                {
                  'area' => '0.400',
                  'type' => 'V',
                  'atom2' => {
                               'number' => '461',
                               'res_name' => 'SER',
                               'res_number' => '59',
                               'name' => 'OG'
                             },
                  'atom1' => {
                               'number' => '2226',
                               'res_name' => 'ASN',
                               'res_number' => '318',
                               'name' => 'CB'
                             }
                },
              ]

This corresponds to the information of one contact. Here, 'atom1'
refers to the atom belonging to the first of the two polypeptides
given to the 'chains' method; 'atom2' refers to the second. The fields
'number' and 'name' refer to the atom's number and name, respectively.
The fields 'res_name' and 'res_number' indicate the atom's parent
residue name and residue id. 'type' indicates one of the five
non-covalent bonds that the program predicts:

=over 5

=item * B<V:> Van der Waals (packing interaction)
=item * B<I:> Ion pair 
=item * B<S:> Salt bridge (hydrogen-bonded ion pair)
=item * B<H:> Hydrogen bond (hydrogen-bonded ion pair)

=back

Every bond type has the 'area' attribute, which indicates the surface
(in square Angstroms) of the interaction. In addition, all N-O
contacts (I, S and H) have a 'Rno' value that represents the N-O
distance. Directional contacts (S and H) also have an 'angle' feature
that indicates the contact angle. For salt bridges, estimations of the
free energy of hydrogen bond (dGhb) and free energy of ionic pair
(dGip) are also given.

The C<@$by_res> array is organized as follows:

   $by_res = [
               {
                 'area' => '20.033',
                 'res1' => {
                             'number' => '318',
                             'name' => 'ASN'
                           },
                 'res2' => {
                             'number' => '59',
                             'name' => 'SER'
                           }
               },
             ]

Here, bond type is obviously not given since the contact can possibly
involve more than one atom-atom contact type. 'res1' and 'res2'
correspond to the residues of the first and second chain ID given,
respectively. 'area' is the sum of every atom-atom contact that the
residue pair has. Their names (as three-letter residue names) and
number are given as hashrefs.

=cut

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

has 'program_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Qcontacts',
    lazy    => 1,
);

has program_dir => (
    is  => 'rw',
    isa => 'Str',
);

has arguments => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy       => 1,
    auto_deref => 1,
    builder    => '_set_arguments',
);

# Private methods

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
        -probe => $self->probe_radius,
    };
}

no Moose;
1
