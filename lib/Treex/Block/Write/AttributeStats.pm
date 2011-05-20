package Treex::Block::Write::AttributeStats;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

has '+language' => ( required => 1 );

# The statistics storage (a multi-level hash, with one level for each attribute).
has '_attrib_stats' => (
    isa     => 'HashRef',
    is      => 'rw',
    default => sub { {} }
);

has 'separator' => (
    isa     => 'Str',
    is      => 'ro',
    default => "\t"
);

sub _process_tree() {

    my ( $self, $tree ) = @_;

    foreach my $node ( $tree->get_descendants ) {
        $self->_process_node($node);
    }
}

# Gathers the statistics for one node.
sub _process_node() {

    my ( $self, $node ) = @_;

    my $ref = $self->_attrib_stats;

    # Proceed for each needed attribute (stored in a multi-level hash)
    for ( my $i = 0; $i < @{ $self->_attrib_list }; ++$i ) {

        my $attr = $self->_attrib_list->[$i];
        my $val  = $node->get_attr($attr);

        if ( !$val ) {
            $val = '';
        }

        # Store the total count for the given attribute (at this hash level)
        $ref->{'__COUNT__'} = $ref->{'__COUNT__'} ? $ref->{'__COUNT__'} + 1 : 1;

        # If further hash levels are needed, create them and proceed into them
        if ( $i < @{ $self->_attrib_list } - 1 ) {
            if ( !$ref->{$val} ) {
                $ref->{$val} = {};
            }
            $ref = $ref->{$val};
        }

        # We are at the end of the multi-level hash, don't go deeper, just collect the value
        else {
            $ref->{$val} = $ref->{$val} ? $ref->{$val} + 1 : 1;
        }
    }
}

# Collects statistics for individual files
override 'process_document' => sub {

    my $self = shift;
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    super;

    log_info( 'Stats collected for : ' . $document->path . ', total ' . $self->_attrib_stats->{'__COUNT__'} . ' entries' );
};

# Prints the whole statistics at the end of the process
sub DEMOLISH {

    my ($self) = @_;

    $self->_print_stats( $self->_attrib_stats, 'TOTAL', 0 );
}

# Prints the specified part of the statistics (designed to be recursive)
sub _print_stats {

    my ( $self, $part, $caption, $depth ) = @_;

    # find out the total count for the given portion
    my $total = ref $part eq 'HASH' ? $part->{'__COUNT__'} : $part;

    # shift for the given depth
    for ( my $i = 0; $i < $depth; ++$i ) {
        print { $self->_file_handle } $self->separator;
    }

    # print the statistics
    print { $self->_file_handle } $caption . $self->separator . $total . "\n";

    if ( ref $part eq 'HASH' ) {    # recurse into sub-statistics

        delete $part->{'__COUNT__'};

        foreach my $key (
            sort
            {
                # sort by total counts of the portions or by the counts for the given value
                return $part->{$b} <=> $part->{$a} if ( ref $part->{$a} ne 'HASH' );
                return $part->{$b}->{'__COUNT__'} <=> $part->{$a}->{'__COUNT__'};
            }
            keys %{$part}
            )
        {

            # print the sub-statistics
            $self->_print_stats( $part->{$key}, $key, $depth + 1 );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::AttributeStats

=head1 DESCRIPTION

This prints (tab-separated by default) CSV statistics about the given tree node attributes in relation to each other, i.e.
if the attributes C<functor> and C<formeme> are given, this prints out the number of occurrences of each functor and
for each functor, the number of occurrences of all formemes together with this functor.   

=head1 ATTRIBUTES

=over

=item C<language>

This parameter is required.

=item C<layer>

The annotation layer for which the statistics should be printed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-separated list of attributes (relating to the tree nodes on the specified layer) for which the statistics 
should be printed. This parameter is required.

=item C<separator>

The CSV file separator character. Tab character is the default.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
