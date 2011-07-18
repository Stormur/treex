package Treex::Block::Write::AttributeSentences;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

has '+language' => ( required => 1 );

has 'separator' => ( isa => 'Str', is => 'ro', default => ' ' );

has 'attr_sep' => ( isa => 'Str', is => 'ro', default => '|' );

sub _process_tree() {

    my ( $self, $tree ) = @_;

    my @nodes = $tree->get_descendants( { ordered => 1 } );

    print { $self->_file_handle } join $self->separator, map { join $self->attr_sep, @{ $self->_get_info_list($_) } } @nodes;

    print { $self->_file_handle } "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::AttributeSentences

=head1 DESCRIPTION

This prints the values of the selected attributes for all nodes in a tree, one sentence per line. 

For multiple-valued attributes (lists) and dereferencing attributes, please see L<Treex::Block::Write::LayerAttributes>. 

=head1 ATTRIBUTES

=over

=item C<language>

The selected language. This parameter is required.

=item C<attributes>

The name of the attributes whose values should be printed for the individual nodes. This parameter is required.

=item C<layer>

The annotation layer where the desired attribute is found (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<separator>

The separator character for the individual nodes within one sentence. Space is the default.

=item C<attr_sep>

The separator character for the individual attribute values for one node. Vertical bar ("|") is the default.

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
