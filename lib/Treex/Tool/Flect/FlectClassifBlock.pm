package Treex::Tool::Flect::FlectClassifBlock;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Flect::Classif;
use Treex::Core::Resource;
use YAML::Tiny;
use autodie;

with 'Treex::Block::Write::AttributeParameterized';

has '+attributes' => ( builder => '_build_attributes', lazy_build => 1 );

has '+modifier_config' => ( builder => '_build_modifier_config', lazy_build => 1 );

has _flect => ( is => 'rw', isa => 'Maybe[Treex::Tool::Flect::Classif]' );

has model_file => ( is => 'ro', isa => 'Str', required => 1 );

has features_file => ( is => 'ro', isa => 'Str', required => 1 );

has _features_file_data => ( is => 'ro', isa => 'HashRef', builder => '_build_features_file_data', lazy_build => 1 );

sub _build_attributes {
    my ($self) = @_;
    return $self->_features_file_data->{sources};
}

# Take the attribute modifier configuration from the config file, if none is given explicitly
sub _build_modifier_config {
    my ($self) = @_;
    return _parse_modifier_config( $self->_features_file_data->{modifier_config} );
}

sub _build_features_file_data {
    my ($self) = @_;
    return {} if ( not $self->features_file );

    my $cfg = YAML::Tiny->read( Treex::Core::Resource::require_file_from_share( $self->features_file ) );
    $cfg = $cfg->[0];

    my $feats = {
        labels  => [ map { my $val = $_->{label} // $_->{source}; chomp $val; $val =~ s/\s+/\|/g; $val } @{ $cfg->{features} } ],
        sources => [ map { $_->{source} } @{ $cfg->{features} } ],
        types   => [ map { 
            my $srcs = $_->{label} // $_->{source}; 
            $srcs =~ s/(\S+)/STRING/g;
            my $val = $_->{type} // $srcs;
            chomp $val;
            $val =~ s/\s+/\|/g; 
            $val
        } @{ $cfg->{features} } ],
        modifier_config => $cfg->{modifier_config},
    };
    return $feats;
}

sub process_start {

    my ($self) = @_;

    my $model = Treex::Core::Resource::require_file_from_share( $self->model_file );

    my $flect = Treex::Tool::Flect::Classif->new(
        {
            model_file          => $model,
            features            => $self->_features_file_data->{labels},
            feature_types       => $self->_features_file_data->{types},
        }
    );
    $self->_set_flect($flect);
}

sub classify_nodes {
    my ( $self, @nodes ) = @_;

    my @data = map { join( '|', _escape( $self->_get_info_list($_) ) ) } @nodes;

    my $classes = $self->_flect->classify( \@data );
    return @$classes;
}

sub _escape {
    my ($list) = @_;
    return map { $_ = '' if ( not defined $_ ); $_ =~ s/'/\\'/g; $_ =~ s/\|/&pipe;/; $_ } @$list;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Flect::FlectClassifBlock

=head1 DESCRIPTION

A generic block that uses Flect L<http://ufal.mff.cuni.cz/flect> to classify nades.

This requires a trained Flect model and features list in YAML format, which are passed to the
class as C<model_file> and C<features_file> properties.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
