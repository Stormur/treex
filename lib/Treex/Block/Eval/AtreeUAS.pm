package Treex::Block::Eval::AtreeUAS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'eval_is_member' => ( is => 'rw', isa => 'Bool', default => 0 );

my $number_of_nodes;
my %same_as_ref;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $ref_zone = $bundle->get_zone( $self->language, $self->selector );
    my @ref_parents = map { $_->get_parent->ord } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_is_member = map { $_->is_member ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @compared_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();

    $number_of_nodes += @ref_parents;

    foreach my $compared_zone (@compared_zones) {
        my @parents = map { $_->get_parent->ord } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_member = map { $_->is_member ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );

        if ( @parents != @ref_parents ) {
            log_fatal 'There must be the same number of nodes in compared trees';
        }
        my $label = $compared_zone->get_label;
        foreach my $i ( 0 .. $#parents ) {

            if ( $parents[$i] == $ref_parents[$i] && ( !$self->eval_is_member || $is_member[$i] == $ref_is_member[$i] ) ) {
                $same_as_ref{$label}++;
            }
        }
    }
}

END {
#    print "total\t$number_of_nodes\n";
    foreach my $zone_label ( keys %same_as_ref ) {
        print "$zone_label\t$same_as_ref{$zone_label}/$number_of_nodes\t" . ( $same_as_ref{$zone_label} / $number_of_nodes ) . "\n";
    }
}

1;

=over

=item Treex::Block::Eval::AtreeUAS

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
