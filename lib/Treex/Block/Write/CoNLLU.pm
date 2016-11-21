package Treex::Block::Write::CoNLLU;

use strict;
use warnings;
use Moose;
use Lingua::Interset qw(encode);
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'print_id'                         => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'print sent_id in CoNLL-U comment before each sentence' );
has 'xpostag'                          => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'include a treebank-specific tag in the XPOSTAG column?' );
has 'randomly_select_sentences_ratio'  => ( is => 'rw', isa => 'Num',  default => 1 );
has 'alignment'                        => ( is => 'ro', isa => 'Bool', default => 1, documentation => 'print alignment links in the 9th column' );

has _was => ( is => 'rw', default => sub{{}} );

has '+extension' => ( default => '.conllu' );

sub process_atree {
    my ($self, $tree) = @_;

    # if only random sentences are printed
    return if(rand() > $self->randomly_select_sentences_ratio());
    my @nodes = $tree->get_descendants({ordered => 1});
    # Empty sentences are not allowed.
    return if(scalar(@nodes)==0);
    # Print sentence (bundle) ID as a comment before the sentence.
    if ($self->print_id) {
        my $sent_id = $tree->get_bundle->id;
        $sent_id .= '/' . $tree->get_zone->get_label;
        print {$self->_file_handle} "\# sent_id $sent_id\n";
    }
    # Print the original CoNLL-U comments for this sentence if present.
    my $comment = $tree->get_bundle->wild->{comment};
    if ($comment)
    {
        chomp $comment;
        $comment =~ s/\n/\n# /g;
        say {$self->_file_handle()} '# '.$comment;
    }
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $wild = $node->wild();
        my $fused = $wild->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $wild->{fused_end};
            my $last_fused_node_no_space_after = 0;
            # We used to save the ord of the last element with every fused element but now it is no longer guaranteed.
            # Let's find out.
            if(!defined($last_fused_node_ord))
            {
                for(my $j = $i+1; $j<=$#nodes; $j++)
                {
                    $last_fused_node_ord = $nodes[$j]->ord();
                    $last_fused_node_no_space_after = $nodes[$j]->no_space_after();
                    last if(defined($nodes[$j]->wild()->{fused}) && $nodes[$j]->wild()->{fused} eq 'end');
                }
            }
            else
            {
                my $last_fused_node = $nodes[$last_fused_node_ord-1];
                log_fatal('Node ord mismatch') if($last_fused_node->ord() != $last_fused_node_ord);
                $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            }
            my $range = '0-0';
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $range = "$first_fused_node_ord-$last_fused_node_ord";
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            my $form = $wild->{fused_form};
            my $misc = $last_fused_node_no_space_after ? 'SpaceAfter=No' : '_';
            print { $self->_file_handle() } ("$range\t$form\t_\t_\t_\t_\t_\t_\t_\t$misc\n");
        }
        my $ord = $node->ord();
        my $form = $node->form();
        my $lemma = $node->lemma();
        # We want to write the original, corpus-specific POS tag in the POSTAG column.
        # It is not always clear where we should find it.
        # At present I take conll/pos because that is where the original tag survives the
        # HamleDT harmonization process (orig -> prague -> ud). If it is not defined,
        # I take tag as back-off.
        ###!!! It would be better to use a block parameter to let the user specify what tag we should use.
        ###!!! Much in the same fashion as the attributes in Write::CoNLLX are selected.
        my $tag = $node->conll_pos();
        $tag = $node->tag() if(!defined($tag) || $tag eq '');

        # If no iset feature is set, we want to print "_" in the FEATS and UPOS columns.
        # Unfortunately, it is difficult to detect this case
        # because $node->iset() creates new Lingua::Interset::FeatureStructure,
        # which has all (60) features set to an empty string.
        # Using encode('mul::uposf', $isetfs) results in UPOS='X'.
        # So we need to access directly $node->{iset}.
        my ($upos, $feat);
        if ($node->{iset}){
            my $isetfs = $node->iset();
            my $upos_features = encode('mul::uposf', $isetfs);
            ($upos, $feat) = split(/\t/, $upos_features);
        } else {
            ($upos, $feat) = ('_', '_');
        }
        my $pord = $node->get_parent()->ord();
        my @misc;
        @misc = split(/\|/, $wild->{misc}) if(exists($wild->{misc}) && defined($wild->{misc}));
        # In the case of fused surface token, SpaceAfter=No may be specified for the surface token but NOT for the individual syntactic words.
        if($node->no_space_after() && !defined($wild->{fused}))
        {
            unshift(@misc, 'SpaceAfter=No');
        }
        # If transliteration of the word form to Latin (or another) alphabet is available, put it in the MISC column.
        if(defined($node->translit()))
        {
            push(@misc, 'Translit='.$node->translit());
        }
        if(defined($node->wild()->{lemma_translit}) && $node->wild()->{lemma_translit} !~ m/^_?$/)
        {
            push(@misc, 'LTranslit='.$node->wild()->{lemma_translit});
        }
        ###!!! (Czech)-specific wild attributes that have been cut off the lemma.
        ###!!! In the future we will want to make them normal attributes.
        ###!!! Note: the {lid} attribute is now also collected for other treebanks, e.g. AGDT and LDT.
        if(exists($wild->{lid}) && defined($wild->{lid}))
        {
            if(defined($lemma))
            {
                push(@misc, "LId=$lemma-$wild->{lid}");
            }
            else
            {
                log_warn("UNDEFINED LEMMA: $ord $form $wild->{lid}");
            }
        }
        if(exists($wild->{lgloss}) && defined($wild->{lgloss}) && ref($wild->{lgloss}) eq 'ARRAY' && scalar(@{$wild->{lgloss}}) > 0)
        {
            my $lgloss = join(',', @{$wild->{lgloss}});
            push(@misc, "LGloss=$lgloss");
        }
        if(exists($wild->{lderiv}) && defined($wild->{lderiv}))
        {
            push(@misc, "LDeriv=$wild->{lderiv}");
        }
        if(exists($wild->{lnumvalue}) && defined($wild->{lnumvalue}))
        {
            push(@misc, "LNumValue=$wild->{lnumvalue}");
        }
        my $misc = scalar(@misc)>0 ? join('|', @misc) : '_';
        my $deprel = $node->deprel();
        # CoNLL-U columns: ID, FORM, LEMMA, UPOSTAG, XPOSTAG(treebank-specific), FEATS, HEAD, DEPREL, DEPS(additional), MISC
        # Make sure that values are not empty and that they do not contain spaces.
        my $xpostag = $self->xpostag() ? $tag : '_';

        my $relations = '_';
        if ($self->alignment) {
            my ($al_nodes, $al_types) = $node->get_aligned_nodes({directed=>1});
            if (@$al_nodes) {
                $relations = join '|', map {$self->_print_alignment($al_nodes->[$_], $al_types->[$_])} (0 .. @$al_nodes-1);
            }
        }

        my @values = ($ord, $form, $lemma, $upos, $xpostag, $feat, $pord, $deprel, $relations, $misc);
        @values = map
        {
            my $x = $_ // '_';
            $x =~ s/^\s+//;
            $x =~ s/\s+$//;
            $x =~ s/\s+/_/g;
            $x = '_' if($x eq '');
            $x
        }
        (@values);
        print { $self->_file_handle() } join("\t", @values)."\n";
    }
    print { $self->_file_handle() } "\n" if($tree->get_descendants());
    return;
}

sub _print_alignment {
    my ($self, $node, $type) = @_;
    my $id = $node->get_bundle->id;
    $id .= '/' . $node->get_zone->get_label;
    $id .= '#' . $node->ord;
    my $t = $type =~ /int/  ? 'int' :
            $type =~ /gdfa/ ? 'gdfa':
            $type =~ /left/ ? 'left':
            $type =~ /right/? 'right':
            $type =~ /rule|supervised/ ? 'rule' : 'other';
    return "$id:align_$t";
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLLU

=head1 DESCRIPTION

Document writer for the CoNLL-U data format
(L<http://universaldependencies.github.io/docs/format.html>).

=head1 PARAMETERS

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

=back

=head1 METHODS

=over

=item process_atree

Saves (prints) the CoNLL-U representation of one sentence (one dependency tree).

=back

=head1 AUTHOR

Daniel Zeman

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
