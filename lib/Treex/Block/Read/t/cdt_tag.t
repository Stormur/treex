#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Block::Read::CdtTag;


my $reader = Treex::Block::Read::CdtTag->new(
    from => join ',',glob "*.tag",
);

my @documents;
my $new_document;
while ($new_document = $reader->next_document) {
    push @documents, $new_document;
}


is(scalar(@documents), 3, q(All test tag files loaded));

done_testing();


END {
# delete temporary files
}
