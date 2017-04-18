package Treex::Tool::Coreference::NodeFilter::RelPron;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

sub is_relat {
    my ($tnode, $args) = @_;
    if ($tnode->language eq 'cs') {
        return _is_relat_cs($tnode, $args);
    }
    if ($tnode->language eq 'en') {
        return _is_relat_en($tnode, $args);
    }
    # Russian, German
    return _is_relat_prague($tnode, $args);
}

sub is_coz_cs {
    my ($tnode) = @_;
    my $anode = $tnode->get_lex_anode;
    return 0 if !$anode;
    return $anode->tag =~ /^.E/;
}

sub is_co_cs {
    my ($tnode) = @_;
    my $anode = $tnode->get_lex_anode;
    return 0 if !$anode;
    return $anode->tag =~ /^.Q/;
}

sub _is_relat_cs {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_relat_cs_a($node, $args);
    }
    else {
        return _is_relat_cs_t($node, $args);
    }
}

sub _is_relat_cs_t {
    my ($tnode, $args) = @_;

    #my $is_via_indeftype = _is_relat_via_indeftype($tnode);
    #return ($is_via_indeftype ? 1 : 0);
    #if (defined $is_via_indeftype) {
    #    return $is_via_indeftype;
    #}
    
    my $anode = $tnode->get_lex_anode;
    return 0 if !$anode;
    return _is_relat_cs_a($anode, $args);
}

sub _is_relat_cs_a {
    my ($anode, $args) = @_;

    my $has_relat_tag = _is_relat_prague_via_tag($anode, $args);
    my $is_relat_lemma = _is_relat_cs_via_lemma($anode); 
    
    #return $has_relat_tag;
    return $has_relat_tag || $is_relat_lemma;
    
    #return $is_relat_lemma;
}

sub _is_relat_en {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_relat_en_a($node, $args);
    }
    else {
        return _is_relat_en_t($node, $args);
    }
}

sub _is_relat_en_t {
    my ($tnode) = @_;
    #my $is_via_indeftype = _is_relat_via_indeftype($tnode);
    #return $is_via_indeftype ? 1 : 0;
    my $anode = $tnode->get_lex_anode();
    return _is_relat_en_a($anode);
}

sub _is_relat_en_a {
    my ($anode) = @_;
    return 0 if (!defined $anode);
    return 1 if ($anode->tag =~ /^W/);
    return 1 if ($anode->tag eq "IN" && $anode->lemma eq "that" && !$anode->get_children());
    return 0;
}

sub _is_relat_prague {
    my ($node, $args) = @_;

    if ($node->get_layer eq "a") {
        return _is_relat_prague_a($node, $args);
    }
    else {
        return _is_relat_prague_t($node, $args);
    }
}

sub _is_relat_prague_t {
    my ($tnode, $args) = @_;
    #my $is_via_indeftype = _is_relat_via_indeftype($tnode);
    #return $is_via_indeftype ? 1 : 0;
    my $anode = $tnode->get_lex_anode();
    return 0 if (!defined $anode);
    return _is_relat_prague_a($anode, $args);
}

sub _is_relat_prague_a {
    my ($anode, $args) = @_;
    # Russian, German
    # Russian parsed by UDPipe trained on HamleDT uses the same tags as Czech, except for pronouns
    # pronouns must be fixed by hand in W2A::RU::FixPronouns
    return _is_relat_prague_via_tag($anode, $args);
}

# so far the best
# not annotated on the Czech side of PCEDT
# => must be copied there from "cs_src"
sub _is_relat_via_indeftype {
    my ($tnode) = @_;
    my $indeftype = $tnode->gram_indeftype;
    return undef if (!defined $indeftype);
    return ($indeftype eq "relat") ? 1 : 0;
}

# "kde" and "kdy" are missing since their tags are Dd------
sub _is_relat_prague_via_tag {
    my ($anode, $args) = @_;
    # 1 = Relative possessive pronoun jehož, jejíž, ... (lit. whose in subordinate relative clause) 
    # 4 = Relative/interrogative pronoun with adjectival declension of both types (soft and hard) (jaký, který, čí, ..., lit. what, which, whose, ...) 
    # 9 = Relative pronoun jenž, již, ... after a preposition (n-: něhož, niž, ..., lit. who)
    # E = Relative pronoun což (corresponding to English which in subordinate clauses referring to a part of the preceding text) 
    # J = Relative pronoun jenž, již, ... not after a preposition (lit. who, whom) 
    # K = Relative/interrogative pronoun kdo (lit. who), incl. forms with affixes -ž and -s (affixes are distinguished by the category VAR (for -ž) and PERSON (for -s))
    # Q = Pronoun relative/interrogative co, copak, cožpak (lit. what, isn't-it-true-that)
    # ? = Numeral kolik (lit. how many/how much)
    
    my $arg_iswhat = $args->{is_what} // 0;
    my $iswhat = $anode->tag =~ /^.Q/;
    return 0 if !ternary_arg($arg_iswhat, $iswhat);

    my $isother = $anode->tag =~ /^.[149EJK\?]/;
    
    return $iswhat || $isother;
}

# there is a problem with "již"
my %relat_lemmas = map {$_ => 1}
    qw/kde kdy/;
    #qw/co což jak jaký jenž již kam kde kdo kdy kolik který odkud/;

sub _is_relat_cs_via_lemma {
    my ($anode) = @_;
    return $relat_lemmas{Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma, 0)}; 
}

# TODO doc

1;
