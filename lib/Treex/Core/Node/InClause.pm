package Treex::Core::Node::InClause;
use Moose::Role;
use Treex::Core::Log;
use List::Util qw(first); # TODO: this wouldn't be needed if there was Treex::Common for roles

has clause_number => (
    is => 'rw',
    isa => 'Maybe[Int]',
    documentation => 'ordinal number that is shared by all nodes of a clause',
);

has is_clause_head => (
    is => 'rw',
    isa => 'Bool',
    documentation => 'Is this node a head of a finite clause?',
); 

sub get_clause_root {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self      = shift;
    my $my_number = $self->get_attr('clause_number');
    log_warn( 'Attribut clause_number not defined in ' . $self->get_attr('id') )
        if !defined $my_number;
    return $self if !$my_number;

    my $highest = $self;
    my $parent  = $self->get_parent();
    while ( $parent && ( $parent->get_attr('clause_number') || 0 ) == $my_number ) {
        $highest = $parent;
        $parent  = $parent->get_parent();
    }
    if ( $parent && !$highest->get_attr('is_member') && $parent->is_coap_root() ) {
        my $eff_parent = first { $_->get_attr('is_member') && ( $_->get_attr('clause_number') || 0 ) == $my_number } $parent->get_children();
        return $eff_parent if $eff_parent;
    }
    return $highest;
}

# Clauses may by split in more subtrees ("Peter eats and drinks.")
sub get_clause_nodes {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self        = shift;
    my $root        = $self->get_root();
    my @descendants = $root->get_descendants( { ordered => 1 } );
    my $my_number   = $self->get_attr('clause_number');
    return grep { $_->get_attr('clause_number') == $my_number } @descendants;
}

# TODO: same purpose as get_clause_root but instead of clause_number uses is_clause_head
sub get_clause_head {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;
    my $node = $self;
    while ( !$node->get_attr('is_clause_head') && $node->get_parent() ) {
        $node = $node->get_parent();
    }
    return $node;
}

# taky by mohlo byt neco jako $node->get_descendants({within_clause=>1});
sub get_clause_descendants {
    log_fatal 'Incorrect number of arguments' if @_ != 1;
    my $self = shift;

    my @clause_children = grep { !$_->get_attr('is_clause_head') } $self->get_children();
    return ( @clause_children, map { $_->get_clause_descendants() } @clause_children );
}

1;

__END__

=head1 NAME

Treex::Core::Node::InClause

=head1 DESCRIPTION

Moose role for nodes in trees where (linguistic) clauses can be recognized
based on attributes C<clause_number>.

=head1 ATTRIBUTES

=over

=item clause_number


=back

=head1 METHODS

=over

=item my $clause_root_node = $node->get_clause_root();

Return the root (head) node of a clause

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

