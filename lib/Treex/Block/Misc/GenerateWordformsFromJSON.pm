package Treex::Block::Misc::GenerateWordformsFromJSON;

use Moose;
use Treex::Core::Common;
use JSON;
use File::Slurp;

extends 'Treex::Core::Block';

has surface_forms => ( is => 'ro', 'isa' => 'Str', required => 1 );

has _sf => ( is => 'rw', 'isa' => 'HashRef', builder => '_build_sf', lazy_build => 1 );

sub _build_sf {
    my ($self) = @_;
    my $json_data = decode_json( read_file( $self->surface_forms ) );

    my %sf = ();
    while ( my ( $slot, $val_data ) = each %$json_data ) {
        while ( my ( $val, $forms_list ) = each %$val_data ) {
            foreach my $flt (@$forms_list) {
                my ( $lemma, $form, $tag ) = split /\t/, $flt;
                $sf{$lemma} = {} if ( !defined( $sf{$lemma} ) );
                $sf{$lemma}->{$tag} = $form;
            }
        }
    }
    return \%sf;
}

my @CATEGORIES = qw(pos subpos gender number case possgender possnumber
    person tense grade negation voice reserve1 reserve2);

sub process_anode {
    my ( $self, $anode ) = @_;
    return if defined $anode->form;
    
    my $lemma = $anode->lemma // '';
    return if !defined( $self->_sf->{$lemma} );

    my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');

    my $tag_regex = join "", map { $anode->get_attr("morphcat/$_") // '.' } @CATEGORIES;
    
    if ($tnode and $tnode->formeme =~ /^n:/ ){
        $tag_regex =~ s/^(..)../$1../;  # for nouns, ignore number and gender for our purpose
    }
    foreach my $tag ( keys %{ $self->_sf->{$lemma} } ) {
        if ( $tag =~ /$tag_regex/ ) {
            $anode->set_form( $self->_sf->{$lemma}->{$tag} );
            $anode->set_tag($tag);
            $anode->set_morphcat_pos('!');  # avoid further inflection
            return;
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::GenerateWordformFromJSON

=head1 DESCRIPTION

Generate wordforms from a simple JSON dictionary. Used to postprocess t-trees generated by 
Tgen L<http://github.com/UFAL-DSG/tgen>, for filling-in names.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
