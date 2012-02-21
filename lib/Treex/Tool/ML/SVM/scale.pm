use strict;
use warnings;

my %pos;
my %models;
my $posIndex=1;
my $modelIndex=1;
open (MYFILE, '>input');
open (MYMODELKEY, '>modelkey');
open (MYPOSKEY, '>poskey');
while (<>){
  my @tokens=split ("\t",$_);
  
  if(exists $models{$tokens[0]}){
    $tokens[0]=$models{$tokens[0]};
  }
  else{
    $models{$tokens[0]}=$modelIndex;
    print MYMODELKEY  $modelIndex."\t". $tokens[0]."\n";
    $tokens[0]=$models{$tokens[0]};
    $modelIndex++;
  }
  
  
  if(exists $pos{$tokens[1]}){
    $tokens[1]=$pos{$tokens[1]};
  }
  else{
    $pos{$tokens[1]}=$posIndex;
    print MYPOSKEY $tokens[1] ."\t".$posIndex ."\n";
    $tokens[1]=$pos{$tokens[1]};
    $posIndex++;
  }
  
  if(exists $pos{$tokens[2]}){
    $tokens[2]=$pos{$tokens[2]};
  }
  else{
    $pos{$tokens[2]}=$posIndex;
    print MYPOSKEY $tokens[2] ."\t".$posIndex ."\n";
    $tokens[2]=$pos{$tokens[2]};
    $posIndex++;
  }
  
  if(exists $pos{$tokens[3]}){
    $tokens[3]=$pos{$tokens[3]};
  }
  else{
    $pos{$tokens[3]}=$posIndex;
    print MYPOSKEY $tokens[3] ."\t".$posIndex ."\n";
    $tokens[3]=$pos{$tokens[3]};
    $posIndex++;
  }
  
 #write to file
 print MYFILE join ("\t",@tokens);
 
}
close (MYFILE); 
close (MYMODELKEY);
close (MYPOSKEY);