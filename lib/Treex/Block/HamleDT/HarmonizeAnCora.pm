package Treex::Block::HamleDT::HarmonizeAnCora;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToPrague;
extends 'Treex::Block::HamleDT::Harmonize';

has auxk_to_root => (is=>'ro', isa=>'Bool', default=>1, documentation=>'attach final punctuation to the technical root' );

sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # The original treebank-specific tag of the AnCora corpora is not interesting and we do not want to keep it for UD.
    foreach my $node ($root->get_descendants())
    {
        $node->set_conll_pos(undef);
    }
    $self->fill_definiteness_of_articles($root);
    # Phrase-based implementation of tree transformations (22.1.2016).
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    if($self->auxk_to_root())
    {
        $self->attach_final_punctuation_to_root($root);
    }
    $self->raise_subordinating_conjunctions($root);
    $self->check_deprels($root);
    return $root;
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
    my $self   = shift;
    my $node   = shift;
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    # CoNLL 2009 uses only two columns.
    return "$conll_pos\t$conll_feat";
}



#------------------------------------------------------------------------------
# Fills the feature of definiteness, which is missing in the original
# annotation of articles.
#------------------------------------------------------------------------------
sub fill_definiteness_of_articles
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_article())
        {
            my $lemma = $node->lemma();
            # Catalan article lemmas: un, el
            # Spanish article lemmas: uno, el
            $node->iset()->set('definiteness', $lemma eq 'el' ? 'def' : 'ind');
        }
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# /net/data/CoNLL/2009/es/doc/tagsets.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        my $pos    = $node->iset()->pos();
        my $ppos   = $parent ? $parent->iset()->pos() : '';
        my $lemma  = $node->lemma;
        # Adjective in leaf node. Could be headed by article! Example:
        # aquests primers tres mesos
        # these first three months
        # TREE: mesos ( aquests/spec ( primers/a , tres/d ) )
        if($deprel eq 'a')
        {
            $deprel = 'Atr';
        }
        # Orational adjunct. Example:
        # segons el Tribunal Suprem
        # according to the Supreme Court
        # NOTE: "segons" is by far the most frequent lemma with the "ao" tag.
        elsif($deprel eq 'ao')
        {
            $deprel = 'Adv';
        }
        # Attribute. The meaning is different from attribute in PDT.
        # els accidents van ser reals
        # the accidents were real
        # ser ( accidents/suj ( els/spec ) , van/v , reals/atr )
        elsif($deprel eq 'atr')
        {
            $deprel = 'Pnom';
        }
        # Conjunction in leaf node. Very rare (errors?) In the examples, coordinating conjunctions are more frequent than subordinating ones.
        # See also "conj" and "coord".
        elsif($deprel eq 'c')
        {
            if($lemma eq 'com' && scalar($node->get_children())==1 && $ppos eq 'verb')
            {
                $deprel = 'AuxC';
                ###!!! We would like to assign $node->get_children()[0]->set_deprel('Adv'). But we should not do it at this moment because the child may be processed by convert_deprels() later.
            }
            elsif($lemma eq 'que' && scalar($node->get_children())==0 && $ppos =~ m/^(adv|conj)$/)
            {
                # Example: més que suficients
                # more than sufficient
                # TREE: suficients/s.a ( més/spec ( que/c ) )
                $deprel = 'AuxY';
            }
            else
            {
                # We have Stanford-style coordination and the conjunction is not head. It must not be labeled Coord,
                # otherwise the bottom-up working phrase builder could confuse it with nested Prague-style coordinations
                # created in previous steps.
                $deprel = 'AuxY';
            }
        }
        # Agent complement.
        # In a passive clause where subject is not the agent, this is the tag for the agent. Most frequently with the preposition "per". Example:
        # jutjat per un tribunal popular
        # tried by a kangaroo court
        elsif($deprel eq 'cag')
        {
            $deprel = 'Obj';
        }
        # Adjunct. Example:
        # gràcies al fet
        # thanks to
        elsif($deprel eq 'cc')
        {
            $deprel = 'Adv';
        }
        # Direct object. Example:
        # Llorens ha criticat la Generalitat/cd
        # Llorens has criticized the Government
        elsif($deprel eq 'cd')
        {
            $deprel = 'Obj';
        }
        # Indirect object. Example:
        # La norma/suj permetrà a/ci les autonomies habilitar/cd altres sales de/cc forma extraordinària.
        # The rule will allow the autonomies to enable other rooms dramatically.
        elsif($deprel eq 'ci')
        {
            $deprel = 'Obj';
        }
        # Subordinating conjunction (que, perquè, si, quan, ...)
        # The conjunction is attached to the head of the subordinate clause, which is attached to the superordinate predicate.
        elsif($deprel eq 'conj')
        {
            ###!!! We will later want to reattach it. Now it is a leaf.
            $deprel = 'AuxC';
        }
        # Coordinating conjunction (i, o, però, ni, ...)
        # The conjunction is attached to the first conjunct.
        elsif($deprel eq 'coord')
        {
            # We have Stanford-style coordination and the conjunction is not head. It must not be labeled Coord,
            # otherwise the bottom-up working phrase builder could confuse it with nested Prague-style coordinations
            # created in previous steps.
            $deprel = 'AuxY';
        }
        # Predicative complement. Noun/prepositional part of compound verbs? Example:
        # ha fet públic
        # have made public
        # TREE: fet ( ha/v , públic/cpred )
        # The most frequent expression tagged cpred is "com_a".
        elsif($deprel eq 'cpred')
        {
            $deprel = 'Obj'; ###!!! Should we invent a new tag for this?
        }
        # Prepositional object. Example:
        # entrar en crisi
        # enter crisis
        elsif($deprel eq 'creg')
        {
            $deprel = 'Obj';
        }
        # Determiner leaf. Example:
        # tots els usuaris
        # all the users
        # TREE: usuaris ( els/spec ( tots/d ) )
        elsif($deprel eq 'd')
        {
            $deprel = 'Atr';
        }
        # Textual element, e.g. introducing expression at the beginning of the sentence. Example:
        # En aquest sentit, ...
        # In this sense, ...
        elsif($deprel eq 'et')
        {
            $deprel = 'Adv';
        }
        # Punctuation mark.
        elsif($deprel eq 'f')
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        # Gerund. Example:
        # perdre el temps intentant debatre amb el grup
        # waste time trying to discuss with the group
        # TREE: debatre ( perdre/infinitiu , temps/cd ( el/spec ) , intentant/gerundi , amb/cc ( grup/sn ( el/spec ) ) )
        elsif($deprel eq 'gerundi')
        {
            ###!!! The structure in the above example is strange.
            ###!!! We would make "debatre" object of "intentant".
            $deprel = 'AuxV';
        }
        # Adjective conjunct, member of adjective group.
        # Adverbial conjunct, member of adverb group.
        # Nominal conjunct, member of noun group.
        elsif($deprel =~ m/^grup\.(a|adv|nom)$/)
        {
            # Sometimes a noun is attached (mistakenly?) to a preposition as grup.nom.
            # It is not probable that the preposition is one conjunct and the noun is the other, and it was not so in any of the occurrences I've seen.
            if($ppos eq 'adp')
            {
                ###!!! The problem is that in these cases we do not know the deprel of the prepositional phrase. It should be annotated at the preposition but it isn't.
                $deprel = 'PrepArg';
            }
            # A few mistakes occur also with determiners (pronouns) and numerals.
            elsif($parent->is_pronominal())
            {
                $deprel = 'DetArg';
            }
            elsif($parent->is_numeral() && !$node->is_numeral())
            {
                $deprel = 'NumArg';
            }
            # In one case a grup.a is attached to a grup.nom; the grup.nom is a conjunct in coordination of nouns while the adjective is just an attribute.
            elsif($deprel eq 'grup.a' && $parent->is_noun())
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'CoordArg';
            }
        }
        # grup.verb is probably an error. There is just one occurrence and it is the first part of a compound coordinating conjunction either-or.
        elsif($deprel eq 'grup.verb')
        {
            $deprel = 'AuxY';
        }
        # Interjection leaf, single occurrence.
        elsif($deprel eq 'i')
        {
            $deprel = 'ExD';
        }
        # Impersonality mark (reflexive pronoun, passive construction).
        elsif($deprel eq 'impers')
        {
            $deprel = 'AuxR';
        }
        # Inserted element (parenthesis). Example:
        # , ha afegit,
        # , he added,
        elsif($deprel eq 'inc')
        {
            # Annotation in PDT (http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s06.html):
            # If it is a particle that would normally get AuxY, it gets AuxY-Pa.
            # If it is a constituent that matches the sentence, just is delimited by commas or brackets: its normal deprel + -Pa.
            # If it is a sentence with predicate and it does not fit in the structure of the surrounding sentence, Pred-Pa.
            # Otherwise, ExD-Pa.
            ###!!! We did not capture parenthesis in HamleDT so far.
            if($pos eq 'verb')
            {
                $deprel = 'Pred';
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        # Infinitive. Example:
        # destacar que toca un violí
        # to emphasize that he plays a violin
        # TREE: toca ( destacar/infinitiu , que/conj , violí/cd ( un/spec ) )
        elsif($deprel eq 'infinitiu')
        {
            ###!!! The structure in the above example is strange.
            ###!!! We would make "que toca" object of "destacar".
            $deprel = 'AuxV';
        }
        # Interjection.
        elsif($deprel eq 'interjeccio')
        {
            $deprel = 'ExD';
        }
        # Non-argumental verb modifier.
        # no, també, només, ja, tampoc
        # not, also, only, already, either
        elsif($deprel eq 'mod')
        {
            if($node->form() =~ m/^no$/i)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Reflexive pronoun.
        # es, s', hi, -se, se
        elsif($deprel eq 'morfema.pronominal')
        {
            $deprel = 'Obj';
        }
        # Reflexive pronoun. See also "impers" and "morfema.pronominal".
        # es, s', -se, se
        # on es podrà participar en tertúlies
        # where one can participate in discussions
        # en els quals es continuarà el seguiment i el control de consums
        # in which one continues to monitor and control consumption
        # al complir-se un segle del naixement de l'artista
        # on completion of a century of the birth of the artist
        elsif($deprel eq 'morfema.verbal')
        {
            $deprel = 'AuxR';
        }
        # Noun leaf. Often within quantification expressions; most frequent word is "resta". Example:
        # un centenar de representants
        # one hundred representatives
        # TREE: representants ( un/spec ( centenar/n , de/s ) )
        elsif($deprel eq 'n')
        {
            # Occasionally a noun attached to another noun is labeled "n": L'Associació Cultural El Galliner ... n(El_Galliner, Associació_Cultural).
            if($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            # Often however it is a noun attached to something that normally should not head a phrase, e.g. a determiner.
            else
            {
                ###!!! We will want to restructure this.
                $deprel = 'DetArg';
            }
        }
        # Negation. Adverbial particle that may modify nouns, adjectives and verbs. Example:
        # persona no grata
        # undesirable person
        elsif($deprel eq 'neg')
        {
            $deprel = 'Neg';
        }
        # Pronoun leaf. Example:
        # el mateix Borrell
        # the same Borrell
        # TREE: Borrell ( el/spec ( mateix/p ) )
        elsif($deprel eq 'p')
        {
            ###!!! We will want to restructure this.
            $deprel = 'DetArg';
        }
        # Participle leaf. Example:
        # distribuïda atenent a criteris
        # distributed according to criteria
        # TREE: atenent ( distribuïda/participi , a/creg ( criteris/sn ) )
        elsif($deprel eq 'participi')
        {
            # If the parent is verb, the participle is a nominal predicate and the verb is copula.
            # que van ser confiscats ... participi(van, confiscats); v(van, ser).
            if($ppos eq 'verb')
            {
                $deprel = 'Pnom';
            }
            else
            {
                ###!!! We will want to restructure this.
                $deprel = 'AdjArg';
            }
        }
        # Reflexive pronoun used to form reflexive passive. Example:
        # See also morfema.pronominal, morfema.verbal and impers.
        # on es va explicar
        # where it was explained
        elsif($deprel eq 'pass')
        {
            #$deprel = 'AuxR';
            # It is not clear whether Spanish deprel=pass (e.g. lemma=se) should have deprel=AuxR or deprel=Obj
            # see https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/a-layer/html/ch03s06x25.html#sereflex-3
            # Currently, the synthesis cannot add nodes with reflexive/passive lemma=se deprel=AuxR, so I prefer deprel=Obj.
            $deprel = 'Obj';
        }
        # Preposition leaf attached to a verb. Example: de, com, a, segons, a_punt_de
        # per mirar de conèixer les circumstàncies
        # to try to meet the circumstances
        elsif($deprel eq 'prep')
        {
            ###!!! We will want to restructure this.
            $deprel = 'AuxP';
        }
        # Adverb leaf. Example:
        # ara fa tan sols un any
        # just a year ago
        # LIT.: now does so only one year
        # TREE: any ( ara/r , fa/v , tan_sols/r , un/d )
        elsif($deprel eq 'r')
        {
            $deprel = 'Adv';
        }
        # Relative pronoun (què, qual, quals, qui, que, on). Example:
        # en el qual
        # in which
        # TREE: en ( qual/relatiu ( el/d ) )
        # But also:
        # ser el que va registrar
        # to be the one that registered
        # TREE: ser ( registrar/atr ( el/spec , que/relatiu , va/v ) )
        ###!!! We would like to restructure this latter example.
        # Occasionally it is a relative determiner attached to a noun, as in "el Care, cuya firma da derecho..." ... relatiu(firma, cuya); suj(da_derecho, firma).
        elsif($deprel eq 'relatiu')
        {
            if($parent->is_noun())
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'PrepArg';
            }
        }
        # Head of subordinate clause. Example:
        # litres que han arribat al riu
        # liters that have reached the river
        # TREE: litres ( arribat/S ( que/suj , han/v , al/cc ( riu/sn ) ) )
        # Infinitive under preposition is also 'S': ... para asegurar la provisión ...
        elsif($deprel eq 'S')
        {
            if($pos eq 'verb' && $ppos eq 'adp')
            {
                $deprel = 'SubArg';
            }
            elsif($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            else
            {
                ###!!! We should look at children to distinguish adverbial clauses. (E.g., is "where" or "when" among the children?)
                ###!!! On the other hand, looking at parent (verba dicendi) could reveal that it is complement clause.
                $deprel = 'Adv'; ###!!! or 'Obj'
            }
        }
        # Preposition leaf. See also "prep". Example:
        # les respostes que s'ha de donar
        # the answers to be given
        # LIT.: the answers that are of giving
        # TREE: respostes ( les/spec , donar/S ( que/suj , s'/pass , ha/v , de/s ) )
        elsif($deprel eq 's')
        {
            ###!!! We will want to restructure this.
            $deprel = 'AuxP';
        }
        # Adjective phrase that does not depend on a verb. Mostly a modifier of noun. Example:
        # una selva petita
        # a small forest
        # TREE: selva ( una/spec , petita/s.a )
        # Sometimes it is the head of a nounless prepositional phrase: fabricantes de electrónica.ADJ.
        elsif($deprel eq 's.a')
        {
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            else
            {
                $deprel = 'Atr';
            }
        }
        # Adjective phrase that depends on a verb.
        # (But in reality, many occurrences I saw do not depend on a verb. Are they annotation errors?)
        # Maybe it is just because of the automatic conversion from phrase trees.
        # 16 examples in PML-TQ depend on prepositions.
        # 11 examples in PML-TQ depend on verbs. But they are neither arguments, nor verbal attributes or nominal predicates.
        # Example:
        # Quan abans comencem, millor.
        # The earlier we start the better.
        # TREE: comencem/sentence ( Quan/conj , abans/cc , ,/f , millor/sa , ./f )
        elsif($deprel eq 'sa')
        {
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            else
            {
                $deprel = 'Atr';
            }
        }
        # Adverb phrase.
        # Occasionally the adverb may appear with a preposition, as in "de ayer" ("ayer" is tagged ADV, not NOUN).
        elsif($deprel eq 'sadv')
        {
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Main predicate or other main head if there is no predicate.
        elsif($deprel eq 'sentence')
        {
            if($pos eq 'verb')
            {
                $deprel = 'Pred';
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        # Noun phrase that is not tagged specifically as subject or object.
        # Most of these cases (83%) are attached to a preposition.
        # Some of the cases where it depends on a noun resemble apposition.
        elsif($deprel eq 'sn')
        {
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            elsif($ppos eq 'conj')
            {
                $deprel = 'SubArg';
            }
            elsif($ppos =~ m/^(verb|adj)$/)
            {
                $deprel = 'Obj';
            }
            elsif($ppos eq 'adv')
            {
                $deprel = 'Adv';
            }
            else
            {
                $deprel = 'Apposition';
            }
        }
        # Prepositional phrase.
        elsif($deprel eq 'sp')
        {
            # We do not want to assign AuxP now. That will be achieved by swapping deprels later.
            # Now we have to figure out the relation of the prepositional phrase to its parent.
            if($ppos =~ m/^(noun|adj|num)$/)
            {
                # adj example: propietària de les mines
                # num example: una de cada tres pessetes
                $deprel = 'Atr';
            }
            elsif($ppos eq 'verb' && $lemma =~ m/^(a|al|d'|de|del)$/i) # '
            {
                $deprel = 'Obj';
            }
            elsif($ppos eq 'verb')
            {
                # Observed with a variety of other prepositions, e.g.: com_a, al_marge_de, sobre, per, en.
                $deprel = 'Adv';
            }
            elsif($ppos eq 'adv')
            {
                $deprel = 'Adv';
            }
            elsif($ppos eq 'adp')
            {
                # Example: per a quatre veterinaris gironins
                # Note that an 'sp' attached to another preposition may also mean coordination: als hospitals, als centres assistencials, mercats i escoles
                # Check whether the parent preposition is to the left and there are at least two siblings in between:
                # the argument of the parent preposition, and a comma or conjunction (or both).
                my @pchildren = $parent->children({'ordered' => 1});
                my $pord = $parent->ord();
                my $nord = $node->ord();
                my @betweench = grep {$_->ord() > $pord && $_->ord() < $nord} (@pchildren);
                my @coordinators = grep {$_->is_coordinator() || $_->is_punctuation()} (@betweench);
                if(scalar(@betweench) >= 2 && scalar(@coordinators) >= 1)
                {
                    $deprel = 'CoordArg';
                }
                else
                {
                    $deprel = 'PrepArg';
                }
            }
            elsif($ppos eq 'conj')
            {
                # Example: com en la passada legislatura
                $deprel = 'SubArg';
            }
            else
            {
                $deprel = 'NR'; ###!!! Where else does it occur?
            }
        }
        # Specifier, i.e. article, numeral or other determiner.
        elsif($deprel eq 'spec')
        {
            # entre els 16 i els 18 anys ... spec(anys, els); spec(els, els).
            if($parent->lemma() eq $lemma && $parent->ord() < $node->ord())
            {
                $deprel = 'CoordArg';
            }
            elsif($lemma =~ m/^(uno|el)$/i && $node->is_leaf())
            {
                $node->iset()->set_prontype('art');
                $deprel = 'AuxA';
            }
            else
            {
                # Example: els 16 anys ... spec(anys, els); z(els, 16).
                # "els" is not leaf but it will become leaf later during transformations.
                $deprel = 'Atr';
            }
        }
        # Subject, including inserted empty nodes (Catalan is pro-drop language) and relative pronouns in subordinate clauses.
        elsif($deprel eq 'suj')
        {
            $deprel = 'Sb';
        }
        # Auxiliary or semi-auxiliary verb. Example:
        # La moció ha estat aprovada.
        # The motion has been approved.
        elsif($deprel eq 'v')
        {
            $deprel = 'AuxV';
        }
        # Vocative. Example:
        # Senyora, escriure una cançó així és molt difícil.
        # Madam, it is very difficult to write a song here.
        elsif($deprel eq 'voc')
        {
            # In PDT, vocatives are annotated as "ExD_Pa" (parenthesis).
            $deprel = "ExD"; ###!!! a co ta parenteze?
        }
        # Date/time. Example:
        # les 22.30 hores
        # 22:30
        # TREE: hores ( les/spec ( 22.30/w ) )
        # This tag is very rare (possible annotation error?) Majority of time expressions is annotated otherwise, e.g.:
        # 1.15 hores
        # TREE: hores ( 1.15/spec )
        elsif($deprel eq 'w')
        {
            # If attached to another number (as the second year in "1903 - 1905"), make it just Atr (is it what PDT would do?)
            if($parent->is_noun() || $parent->is_numeral() || $parent->is_adverb())
            {
                $deprel = 'Atr';
            }
            # However, sometimes it is attached to a determiner.
            else
            {
                $deprel = 'DetArg';
            }
        }
        # Number (expressed in digits) leaf.
        elsif($deprel eq 'z')
        {
            # Sometimes attached quite normally, as in "hace 14 años"; make it Atr.
            # If attached to another number (as the second year in "1903 - 1905"), make it just Atr (is it what PDT would do?)
            # If attached to an adverb, it is almost always the type "más de 500" (sometimes attached to "más", sometimes "más_de" is a collapsed token).
            if($parent->is_noun() || $parent->is_numeral() || $parent->is_adverb())
            {
                $deprel = 'Atr';
            }
            # However, quite often it is attached to a determiner.
            else
            {
                $deprel = 'DetArg';
            }
        }
        $node->set_deprel($deprel);
    }
    # Improve analytical functions for processing of coordinations.
    $self->catch_runaway_conjuncts($root);
}



#------------------------------------------------------------------------------
# Coordinated structures are poorly marked in the Catalan treebank. Before we
# launch coordination processing, this method will try to catch some less
# obvious instances.
#------------------------------------------------------------------------------
sub catch_runaway_conjuncts
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Coordinated nouns, adjectives and adverbs: second and further conjuncts should have deprel=grup.nom (grup.a, grup.adv).
        # If they do, then we have converted their deprel to CoordArg. Unfortunately, many do not; neither do coordinated verbs (clauses).
        # If there is a coordinating conjunction without conjuncts, we should investigate.
        # (Exclude coordinating conjunctions that are children of the root. The root cannot be the first conjunct.)
        if($node->deprel() eq 'AuxY' && !$node->parent()->is_root())
        {
            # Left-headed Stanford style prevails in the treebank. Coordinating conjunction is attached to the left, to the first conjunct.
            # Surprisingly, some coordinating conjunctions are attached to the right (is this an error?)
            # The parent is probably the last conjunct in coordination.
            my $attached_to_left = $node->ord() > $node->parent()->ord();
            if($attached_to_left)
            {
                # The right sibling of the coordinator should be a conjunct. Is there a conjunct?
                my @right_siblings = $node->get_siblings({following_only => 1});
                my @right_conjuncts = grep {$_->deprel() eq 'CoordArg'} (@right_siblings);
                if(scalar(@right_conjuncts)==0)
                {
                    # Coordinating conjunction does not have right sibling marked as conjunct.
                    # Does it have any right neighbor? Does its type somehow match that of their common parent (which would be the first conjunct)?
                    my $rn = $node->get_right_neighbor();
                    my $ln = $node->get_left_neighbor();
                    if($rn)
                    {
                        # Trailing punctuation nodes in the sequence of right siblings are not interesting.
                        my @rswtp = @right_siblings;
                        for(my $i = $#rswtp; $i>=0 && $i<=$#rswtp; $i--)
                        {
                            if($rswtp[$i]->deprel() =~ m/^Aux[GX]$/)
                            {
                                splice(@rswtp, $#rswtp);
                            }
                            else
                            {
                                last;
                            }
                        }
                        my $pos = $rn->iset()->pos();
                        my $ppos = $node->parent()->iset()->pos();
                        if($rn->conll_deprel() eq 'sn' && $node->parent()->conll_deprel() eq 'sn' ||
                        $rn->conll_deprel() eq 'sn' && $ppos eq 'noun' ||
                        $pos eq $ppos ||
                        # There are correct cases where the part of speech of the sibling does not match that of the parent.
                        # What else could we do if the left sibling of the rightmost child is coordinating conjunction?
                        scalar(@rswtp)==1)
                        {
                            $rn->set_deprel('CoordArg');
                        }
                        # Fall back: sometimes the conjunction joins its two neighbors.
                        elsif($ln && $ln->ord() > $node->parent()->ord() && !$ln->is_punctuation())
                        {
                            $node->set_parent($ln);
                            $rn->set_parent($ln);
                            $rn->set_deprel('CoordArg');
                        }
                        # No left neighbors, two right siblings (conjunct and shared modifier).
                        elsif(!$ln || $ln->ord() < $node->parent()->ord())
                        {
                            $rn->set_deprel('CoordArg');
                        }
                    }
                }
            }
            else # attached to right
            {
                # If there is just one left sibling, it is the only candidate for the other conjunct, regardless whether parts of speech match.
                # Punctuation nodes in the sequence of left siblings are not interesting.
                my @left_siblings = $node->get_siblings({preceding_only => 1});
                my @lswp = grep {$_->deprel() !~ m/^Aux[GX]$/} (@left_siblings);
                my $form = $node->form();
                my $search_for = $form eq 'tant' ? 'com' : $form eq 'ja_sigui' ? 'o' : $form eq 'no_només' ? 'sinó_també' : '';
                my @com = grep {$_->lemma() eq $search_for && $_->ord() > $node->ord()} ($node->parent()->get_descendants());
                # Compound conjunctions such as tant-com. Example:
                # tant a nivell nacional com internacional
                # as on national level as on international
                # ORIGINAL TREE: a ( tant/coord , nivell/sn ( nacional/s.a ( com/coord , internacional/grup.a ) ) )
                # DESIRED TREE: a/AuxP ( nivell ( com/Coord ( tant/AuxY , nacional/Atr_Co , internacional/Atr_Co ) ) )
                # Check that tant is leaf to prevent finding com as its dependent (which would lead to a cycle).
                if($node->lemma() =~ m/^(tant|ja_sigui|no_només)$/ && $node->is_leaf() && scalar(@com)==1)
                {
                    my $com = $com[0];
                    $node->set_parent($com);
                    $node->set_deprel('AuxY');
                }
                # Other cases than compound conjunctions.
                elsif(scalar(@lswp)==1)
                {
                    my $first_conjunct = $lswp[0];
                    $first_conjunct->set_deprel('CoordArg');
                }
                # Although in many coordinations the conjunct have all the same part of speech, it is not guaranteed:
                # quines són/v funcions, si hi haurà/v especialitzacions, on estaran/v ubicats i/c altres aspectes/n
                # So we cannot effectively check for matching types of conjuncts.
                else
                {
                    my $conjuncts_found = 0;
                    my $expected_comma = 0;
                    for(my $i = $#left_siblings; $i>=0 && $i<=$#left_siblings; $i--)
                    {
                        my $current = $left_siblings[$i];
                        last if($expected_comma && $current->deprel() ne 'AuxX');
                        $expected_comma = 0;
                        if($current->deprel() ne 'AuxX')
                        {
                            $conjuncts_found++;
                            $current->set_deprel('CoordArg');
                            $expected_comma = 1;
                        }
                    }
                    # If we found no conjuncts, it is not coordination. Example: parenthesis in
                    # IC-V , i més si perd el_seu principal referent , Rafael_Ribó , serà
                    # IC-V , and more if it loses its principal referee , Rafael_Ribó , will be
                    if($conjuncts_found==0)
                    {
                        $node->set_deprel('AuxY');
                    }
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HarmonizeAnCora

This is a common block for harmonization of the Catalan and Spanish AnCora treebanks
in their CoNLL 2009 conversion. The resulting tree is in HamleDT (Prague) style.

Note that we do not call this block directly. To keep the unified language-treebank
hierarchy, both HamleDT::CA::Harmonize and HamleDT::ES::Harmonize exist as extensions
of this block. They might add handling of language-specific phenomena if we encounter
any in future.

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
