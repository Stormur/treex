package Treex::Block::HamleDT::PT::HarmonizeCintilUSD;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'pt::cintil',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Portuguese tree, converts morphosyntactic tags to Interset,
# converts deprel tags to afuns, transforms tree to adhere to the HamleDT
# guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->raise_prepositions($root);
    $self->raise_copulas($root);
    # Make sure that all nodes have known afuns.
    $self->check_afuns($root);
}

#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self = shift;
    my $node = shift;
    # According to the guidelines, the original CINTIL uses tags in form PoS#features,
    # e.g. "CN#mp" (common noun, masculine plural). The old Interset driver in Treex expects this format.
    return $node->conll_pos() . "\#" . $node->conll_feat();
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->conll_deprel();
        my $afun   = 'NR';
        # Attributes that we may have to query.
        my $plemma = $parent->lemma();
        # Convert the labels.
        # Adverbial clause that functions as a modifier (adjunct).
        # Example: a vw ainda n-atil-o tomou qualquer decis-atil-o , porque est-atil-o a analisar/ADVCL as várias hipóteses
        if($deprel eq 'ADVCL')
        {
            $afun = 'Adv';
        }
        # Adverb that functions as adverbial modifier.
        # Example: muito barato
        elsif($deprel eq 'ADVMOD')
        {
            $afun = 'Adv';
        }
        # Adjectival modifier of a noun.
        # Example: um computador barato
        elsif($deprel eq 'AMOD')
        {
            $afun = 'Atr';
        }
        # Apposition. (The examples do not seem similar to what PDT calls apposition.)
        # Example: uma grande vitória para mim/APPOS [APPOS(vitória, mim)]
        elsif($deprel eq 'APPOS')
        {
            $afun = 'Apposition';
        }
        # Auxiliary verb. The examples seem to be reversed. In the following, infinitive is attached as AUX to the auxiliary verb "vai":
        # Example: o governo vai hoje assinar/AUX um protocolo
        elsif($deprel eq 'AUX')
        {
            $afun = 'AuxV'; ###!!! Jak by tohle vypadalo v PDT?
        }
        # Preposition attached to its nominal argument is labeled CASE.
        # Example: em_/CASE o armazém
        elsif($deprel eq 'CASE')
        {
            $afun = 'AuxP';
        }
        # Coordinating conjunction. At least this is the meaning of CC in the original Stanford Dependencies.
        # CINTIL seems to hide the real conjunction but it does not hesitate to label CC the comma in a multi-conjunct coordination.
        # Example: a retirada militar de hebron , os colonatos judeus [CC(colonatos, ,), PARATAXIS(retirada, colonatos)]
        elsif($deprel eq 'CC')
        {
            $afun = 'AuxY';
            $node->wild()->{coordinator} = 1;
        }
        # Clausal complement of a predicate.
        # Example: sei que a herança n-atil-o é boa/CCOMP
        elsif($deprel eq 'CCOMP')
        {
            $afun = 'Obj';
        }
        # Complement (adverbial?)
        # Example: vivem aqui/COMP
        elsif($deprel eq 'COMP')
        {
            $afun = 'Adv';
        }
        # Non-first conjunct is attached to the first conjunct as CONJ.
        elsif($deprel eq 'CONJ')
        {
            $afun = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # Copula is attached to the nominal predicate.
        # Example: este computador é/COP barato
        elsif($deprel eq 'COP')
        {
            $afun = 'Cop';
        }
        # Clausal subject.
        # Example: quem n&atil;o ficou satisfeito com o bombardeamento sobre srebrenica foi lord david owen [CSUBJ(lord, satisfeito)] ###!!!???
        elsif($deprel eq 'CSUBJ')
        {
            $afun = 'Sb';
        }
        # Clausal subject of a passive verb.
        ###!!! There are 9 occurrences of CSUBJPASS in the data and they are probably errors. It is assigned to "que" instead of verbs.
        elsif($deprel eq 'CSUBJPASS')
        {
            $afun = 'Sb';
        }
        # Uncategorized dependency.
        # Example: cerca de dois/DEP [DEP(cerca, dois)]
        elsif($deprel eq 'DEP')
        {
            $afun = 'ExD'; ###!!!???
        }
        # Determiner attached to a noun.
        # Example: o cliente
        elsif($deprel eq 'DET')
        {
            $afun = 'Atr';
        }
        # Direct object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        # Example: o cliente encomendou um computador/DOBJ barato
        elsif($deprel eq 'DOBJ')
        {
            $afun = 'Obj';
        }
        # Indirect object of verb. (If there is one object, it is direct. If there are more, one of them is direct and the rest are indirect.)
        # Example: a criança obedece apenas a_ a m-atil-e/IOBJ
        elsif($deprel eq 'IOBJ')
        {
            $afun = 'Obj';
        }
        # MARK is typically used for subordinating conjunctions attached to the predicate of the subordinate clause.
        # Example: , porque/MARK o empreiteiro de_ a obra o demoveu [MARK(demoveu, porque)]
        elsif($deprel eq 'MARK')
        {
            $afun = 'AuxC';
        }
        # Modifier (adjunct of a verb, not realized as an adverb).
        # Example: o manuel foi a_ a loja com a maria/MOD
        elsif($deprel eq 'MOD')
        {
            $afun = 'Adv';
        }
        # Multi-word expression.
        # Example: vinte/NUMMOD e/MWE dois/MWE computadores
        elsif($deprel eq 'MWE')
        {
            $afun = 'MWE'; ###!!! Atr?
        }
        # NCMOD ###!!!??? It looks like failed conversion of prepositional phrases.
        # Example: chegam discretamente junto/PREPC a_ a cruz alta [PREPC(chegam, junto); NCMOD(junto, cruz)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NCMOD')
        {
            $afun = 'Adv';
        }
        # Negation?
        # Example: que nem/NEG sequer devia ter começado [NEG(devia, nem)]
        elsif($deprel eq 'NEG')
        {
            $afun = 'Adv';
        }
        # Noun phrase that functions as an adverbial modifier.
        # Example: o elemento feminino está favorecido esta semana/NPADVMOD
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NPADVMOD')
        {
            $afun = 'Adv';
        }
        # Noun phrase that functions as subject.
        # Example: este computador/NSUBJ é baratíssimo
        elsif($deprel eq 'NSUBJ')
        {
            $afun = 'Sb';
        }
        # Nominal subject of a passive clause.
        # Example: sabemos que os prémios/NSUBJPASS s-atil-o devidos
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NSUBJPASS')
        {
            $afun = 'Sb';
        }
        # Numerical modifier (cardinal number modifying a counted noun).
        # The NUMMOD label is used for numbers expressed as words.
        # Numbers expressed using digits are labeled NUMBER.
        # Example: sete/NUMMOD outros suspeitos
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NUMMOD')
        {
            $afun = 'Atr';
        }
        # Number expressed using digits. It may have the same function as NUMMOD.
        # Example: tinha 39/NUMBER anos
        # Example: desceu de 7,4780 para 7,4411 por cento
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'NUMBER')
        {
            $afun = 'Atr';
        }
        # Parataxis. Loosely attached clause.
        # Example: analisamos , dialogamos/PARATAXIS
        elsif($deprel eq 'PARATAXIS')
        {
            $afun = 'ExD';
        }
        # Prepositional object of verb.
        # Example: o cliente estava contentíssimo com a compra/POBJ
        elsif($deprel eq 'POBJ')
        {
            $afun = 'Obj';
        }
        # Possessive modifier.
        # Example: de_ os seus/POSS países balcânicos
        elsif($deprel eq 'POSS')
        {
            $afun = 'Atr';
        }
        # Modifier of a possessive modifier.
        # Example: os seus próprios programas [POSSESSIVE(seus, próprios)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'POSSESSIVE')
        {
            $afun = 'Atr';
        }
        # Some coordinating conjunctions are attached as PRECONJ and I do not know why.
        # Example: nem o restaurante... [PRECONJ(restaurante, nem)]
        elsif($deprel eq 'PRECONJ')
        {
            $afun = 'AuxY';
        }
        # Predeterminer.
        # Example: quase/DET tudo/PREDET [PREDET(quase, tudo)]
        elsif($deprel eq 'PREDET')
        {
            $afun = 'Atr';
        }
        # PREPC ###!!!??? It looks like failed conversion of prepositional phrases.
        # Example: chegam discretamente junto/PREPC a_ a cruz alta [PREPC(chegam, junto); NCMOD(junto, cruz)]
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'PREPC')
        {
            $afun = 'AuxP';
        }
        # Punctuation.
        elsif($deprel eq 'PUNCT')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        # Modifier of quantity??? ###!!!
        # Example: entre sete e oito hectares [QUANTMOD(sete, entre)]
        # Example: todos uns quatro computadores [QUANTMOD(quatro, uns)] ... ERROR?
        ###!!! It does not occur in the corrected data of 2014-10-15.
        elsif($deprel eq 'QUANTMOD')
        {
            $afun = 'AuxP';
        }
        # Root token, child of the artificial root node. Typically the main predicate.
        elsif($deprel eq 'ROOT')
        {
            $afun = 'Pred'; ###!!! nebo ExD
        }
        # Clausal complement that does not have its independent subject.
        # It is controlled by a higher clause and its subject is either subject or object of the higher clause.
        # Example: nenhum membro quis falar/XCOMP
        elsif($deprel eq 'XCOMP')
        {
            $afun = 'Obj';
        }
        $node->set_afun($afun);
    }
    # Fix known annotation errors. They include coordination, i.e. the tree may now not be valid.
    # We should fix it now, before the superordinate class will perform other tree operations.
    #$self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Detects coordination in the Stanford shape.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_stanford($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    push(@recurse, $coordination->get_shared_modifiers());
    push(@recurse, $coordination->get_private_modifiers($node));
    return @recurse;
}



#------------------------------------------------------------------------------
# Finds prepositions (AuxP) attached as leaves to their nouns. Reattaches them
# to head the nouns.
#------------------------------------------------------------------------------
sub raise_prepositions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'AuxP' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    if($grandparent->afun() eq 'AuxP')
                    {
                        log_warn('Attaching a preposition under another preposition');
                    }
                    $node->set_parent($grandparent);
                    $parent->set_parent($node);
                    $node->set_is_member($parent->is_member());
                    $parent->set_is_member(0);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Finds copulas (Cop) attached as leaves to their predicates. Reattaches them
# to head the predicates.
#------------------------------------------------------------------------------
sub raise_copulas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'Cop' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            if(defined($parent))
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    $node->set_parent($grandparent);
                    $node->set_afun($parent->afun());
                    $node->set_is_member($parent->is_member());
                    $parent->set_parent($node);
                    $parent->set_afun('Pnom');
                    $parent->set_is_member(0);
                }
            }
        }
    }
}



###################################################################################################



###!!! Tohle probrat a buď převzít, nebo vyhodit.
sub process_zone_martin {
    my ($self, $zone) = @_;

    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);

    my $root  = $zone->get_atree();
    my @nodes = $root->get_descendants();

    # $zone->sentence should contain the (surface, detokenized) sentence string.
    $self->fill_sentence($root);

    # Harmonize tags, forms, lemmas and dependency labels.
    foreach my $node (@nodes) {

        # "em_" -> "em" etc.
        $self->fix_form($node);

        $self->fix_lemma($node);
    }

    # Adverbs (including rhematizers) should not depend on prepositions.
    foreach my $node (@nodes) {
        $self->rehang_rhematizers($node);
    }

    return;
}

sub fix_form {
    my ($self, $node) = @_;
    my $form = $node->form;

    # "em_" -> "em" etc. because the underscore character is reserved for formemes
    $form =~ s/_$//;

    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $form = 'a' if $form eq 'A' && $node->ord > 1;

    $node->set_form($form);
    return;
}

sub fix_lemma {
    my ($self, $node) = @_;
    my $lemma = $node->lemma;

    # Some words don't have assigned lemmas in CINTIL.
    $lemma = $node->form if $lemma eq '_';

    # Automatically analyzed lemmas sometimes include alternatives
    # (e.g. AFASTAR,AFASTADO). Let's hope the first is the most probable one and delete the rest.
    $lemma =~ s/(.),.+/$1/;

    # Otherwise, lemmas in CINTIL are all-uppercase.
    # Let's lowercase it except for proper names.
    $lemma = lc $lemma if $node->iset->nountype ne 'prop';
    $node->set_lemma($lemma);
    return;
}

# Regex for detecting punctuation symbols
my $PUNCT= q{[\[\](),.;:'?-]};

# The surface sentence cannot be stored in the CoNLL format,
# so let's try to reconstruct it.
# This is not needed for the analysis (in real scenario, surface sentences will be on the input),
# but it helps when debugging, so the real sentence is shown in TrEd.
sub fill_sentence {
    my ($self, $root) = @_;
    my $str = join '', map {$_->form . ($_->no_space_after ? '' : ' ')} $root->get_descendants({ordered=>1});

    # Add spaces around the sentence, so we don't need to check for (\s|^) or \b.
    $str = " $str ";

    # For some strange reason feminine definite singular articles are capitalized in CINTIL.
    $str =~ s/ A / a /g;

    # Contractions, e.g. "de_" + "o" = "do"
    $str =~ s/por_ elos/pelos/g;
    $str =~ s/por_ elas/pelas/g;
    $str =~ s/por_ /pel/g; # pelo, pela
    $str =~ s/em_ /n/g;    # no, na, nos, nas, num, numa, nuns, numas
    $str =~ s/a_ a/à/g;    # à, às
    $str =~ s/a_ o/ao/g;   # ao, aos,
    $str =~ s/de_ /d/g;    # do, da, dos, das, dum, duma, duns, dumas, deste, desta,...

    # TODO: detached clitic, e.g. "dá" + "-se-" + "-lhe" + "o" = "dá-se-lho"

    # Punctuation detokenization
    # CINTIL guidelines define special marking for spaces around punctuation "*/" and "\*",
    # but these are not used in CINTIL-DepBank (in conll format).
    if ($self->punctuation_spaces_marked){
        $str =~ s{ \s       # single space
                   (\\\*)?  # $1 = optional "\*" means "space before"
###!!!                   ($PUNCT)  # $2 = punctuation
                   (\*/)?   # $3 = optiona; "*/" meand "space after"
                   \s       # single space
                }
                {($1 ? ' ' : '') . $2 . ($3 ? ' ' : '')}gxe;
    } else {
###!!!        $str =~ s/ ($PUNCT)/$1/g;
    }


    # Remove the spaces around the sentence
    $str =~ s/(^\s+|\s+$)//g;

    # Make sure the first word is capitalized
    $root->get_zone->set_sentence(ucfirst $str);
    return;
}

# Some adverbs (mostly rhematizers "apenas", "mesmo",...) depend on a preposition ("de", "a") in CINTIL.
# However, prepositions should have only one child in the HamleDT/Prague style (except for multi-word prepositions).
# E.g. "A encomenda está mesmo(afun=Adv,parent=em_,newparent=armazém) em_ o armazém . "
#      "A criança obedece apenas(afun=Adv,parent=a_,newparent=mãe) a_ a mãe ."
# Should we differentiate the scope of the rhematizer: "The child obeys only the mother" and "The child only obeys the mother"?
sub rehang_rhematizers {
    my ($self, $node) = @_;
    my $parent = $node->get_parent();
    if ($node->is_adverb && $parent->is_preposition){
        my $sibling = $parent->get_children({following_only=>1, first_only=>1});
        if ($sibling && $sibling->is_noun) {
            $node->set_parent($sibling);
        }
    }
    return;
}

1;

=head1 NAME

Treex::Block::HamleDT::PT::HarmonizeCintilUSD

=head1 DESCRIPTION

Converts the CINTIL Portuguese treebank
(version October 2014, sent by João Rodrigues, Universal Stanford Dependencies)
to the annotation style of HamleDT/Prague.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
