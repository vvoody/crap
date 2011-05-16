#!/usr/bin/perl

# $Id$ 

use strict;
use warnings;
use HTML::Entities;

my $homedir="/home/case/store/jj/nsmdiff_and_stuff";
my $dbfile="/home/www/perl/nsm_csp.tsv";

# NSM version sorting
sub nsm_sorting {
  my (@aa, @bb);
  ($aa[0] = $a ) =~ s/LGB(\d+).*/$1/;
  ($aa[1] = $a ) =~ s/LGB\d+\D+(\d+).*/$1/;
  ($aa[2] = $a ) =~ s/LGB\d+\D+\d+(\D+).*/$1/;
  ($aa[3] = $a ) =~ s/LGB\d+\D+\d+\D+(\d+).*/$1/;
  ($bb[0] = $b ) =~ s/LGB(\d+).*/$1/;
  ($bb[1] = $b ) =~ s/LGB\d+\D+(\d+).*/$1/;
  ($bb[2] = $b ) =~ s/LGB\d+\D+\d+(\D+).*/$1/;
  ($bb[3] = $b ) =~ s/LGB\d+\D+\d+\D+(\d+).*/$1/;
   
  $bb[0] <=> $aa[0] || $bb[1] <=> $aa[1] || $bb[2] cmp $aa[2] || $bb[3] <=> $aa[3];
}


# getting GET values
my %params=map{my($name,$value)=split/\=/;$name => $value} map{split /\&/} $ENV{"QUERY_STRING"};

if ( ! -e $dbfile or ! -e $homedir."/latest_update.txt" or (stat($dbfile))[9] < (stat($homedir."/latest_update.txt"))[9]) {

  my %nsm;
  my %all;
  my %all_descr;

  #loading NSM naming file
  open(FD,"/home/www/perl/nsm_naming.txt") or die "can't load file\n";
  while(<FD>){
    next unless ($_);
    chomp;
    my ($a,$b)=split(" ");
    $nsm{$a}=$b;
  } 
  close(FD);

  my @nsmverl=();
  opendir(DIR,$homedir);
  while(my $nsmver=readdir(DIR)){
    next unless ($nsmver=~/^LGB/ and -d $homedir."/".$nsmver);
    push(@nsmverl,$nsmver);
  }
  closedir(DIR);

  foreach my $nsmver (@nsmverl) {
    opendir(DIFF,$homedir."/".$nsmver);
    while(my $diff=readdir(DIFF)){
      next unless ($diff=~/filediff/);
      my $currprn=0;
      my $currprt=" ";
      my $prntdsc=0;
      my $prdesc=" ";
      open(FD,$homedir."/".$nsmver."/".$diff);
      while(<FD>){
        chomp;
        next if (/^<\s+$/);
        if (/^<\s+(Bug:|\/B:|Title:)\s*(.+?)$/){
          my $f=$2;
          if (/^<\s+(Bug:|\/B:)/) {
            if ($currprn!~/new/i and $currprn > 0){
              $all{"$nsmver#$currprn"}=$currprt unless (exists($all{"$nsmver#$currprn"}) or (exists($all{"$nsmver#$currprn"}) and $all{"$nsmver#$currprn"} eq " "));
              if (exists($all_descr{"$nsmver#$currprn"})){
                $all_descr{"$nsmver#$currprn"}.=$prdesc;
              }else{
                $all_descr{"$nsmver#$currprn"}=$prdesc;
              }
            }
            $f=~s/-.+//;  
            $currprn=$f;
            $currprt=" ";
            $prdesc=" ";
          }elsif (/^<\s+Title:/){
            $currprt=$f;
          }
        }else{
          if (/^<\s+(Codereviewer:|\/C:)/i){
            $prntdsc=1;
            next;
          }
          if (/^<\s+(CustVisibleBehaviorChanged:|\/CVBC:)/i){
            $prntdsc=1;
            next;
          }
          $prntdsc=0 if (/^< Change \d+ on /);
          if ($prntdsc==1){
            s/^<\s+//;
            $prdesc.="$_\n";
          }
        }
      }
      # printing the last bug in the file
      $all{"$nsmver#$currprn"}=$currprt unless (exists($all{"$nsmver#$currprn"}) or (exists($all{"$nsmver#$currprn"}) and $all{"$nsmver#$currprn"} eq "&nbsp;"));
      if (exists($all_descr{"$nsmver#$currprn"})){
        $all_descr{"$nsmver#$currprn"}.=$prdesc;
      }else{
        $all_descr{"$nsmver#$currprn"}=$prdesc;
      }
      close(FD);
    }
    closedir(DIFF);
  }
  open(DB,"> /home/www/perl/nsm_csp.tsv") or die "Can't open file: $!\n";
  foreach my $nsmpr (sort nsm_sorting keys %all){
    my ($nsmver,$pr) = split/#/,$nsmpr;
    my $mainver="";
    if ($nsmver=~/(LGB\d+z\d+)(.*)/){
      $mainver=$nsm{$1} if (exists($nsm{$1}));
    }
    $all{$nsmpr}=HTML::Entities::encode($all{$nsmpr});
    $all_descr{$nsmpr}=HTML::Entities::encode($all_descr{$nsmpr});
    $all{$nsmpr}=~s/\n/<br\/>/g;
    $all_descr{$nsmpr}=~s/\n/<br\/>/g;
    print DB "$nsmver\t$mainver\t$pr\t$all{$nsmpr}\t$all_descr{$nsmpr}\n";
  }
  close(DB);
}

my $pagetitle="patch list with fixes for NSM";

# we start output here
print "Content-type: text/html\n\n\
<html>\
<head>\
<title>$pagetitle</title>\
<STYLE TYPE=\"text/css\">
<!--
body {background-color:#CCCCCC;}
.head1, .head1 TD, .head1 TH { background-color:black; color:#CCCCCC;}
.row1, .row1 TD, .row1 TH { background-color:#99CCFF; color:#000000;}
.row2, .row2 TD, .row2 TH { background-color:#99FFFF; color:#000000;}
-->
</STYLE>
</head>\
<body> 
<h1 align=\"center\"><a href=\"?\">$pagetitle</a></h1>\n";

if (exists($params{'m'}) and $params{'m'}==1 and exists($params{'q'}) and $params{'q'} ne ""){
  print "<p align=\"center\">".$params{'q'}." can be downloaded <a href=\"ftp://dev:abcd1234\@ft-nm-ftp.juniper.net:/%2Ftftpboot/ims/".$params{'q'}."\">here</a></p>";
}

print "<table width=\"90%\" border=\"0\" align=\"center\">\
<form method=\"get\" enctype=\"multipart/form-data\">\
<tr><td align=\"right\">NSM version:</td><td><input type=\"text\" name=\"q\" value=\"";
print $params{'q'} if (exists($params{'q'}));
print "\"/></td></tr>\
<tr><td align=\"right\">PR number:</td><td><input type=\"text\" name=\"prn\" value=\"";
print $params{'prn'} if (exists($params{'prn'}));
print "\"/></td></tr>\
<tr><td align=\"right\">PR title or description:</td><td><input type=\"text\" name=\"prt\" value=\"";
print $params{'prt'} if (exists($params{'prt'}));
print "\"/> (case insensitive)</td></tr>\
<tr><td></td><td><input type=\"submit\" value=\"search\"/></td></tr>\
<tr><td>&nbsp;</td><td><a href=\"?q=LGB13&prt=srx\">example search for all PRs titles with \"SRX\" in them on NSM versions with \"LGB13\"</a></td></tr>";
if (exists($params{'q'}) and $params{'q'} ne ""){
  print "<tr><td>&nbsp;</td><td><a href=\"https://gnats.juniper.net/web/default/do-query?adv=0&OPT_product=EXACT&product=nsm&target=".$params{'q'}."&OPT_target=MATCH&csv=0&columns=synopsis%2Creported-in%2Csubmitter-id%2Cproduct%2Ccategory%2Cseverity%2Cpriority%2Cblocker%2Cplanned-release%2Cstate%2Cresponsible%2Coriginator%2Carrival-date%2Ctarget&op=%26\">gnats search for PRs with target release matching ".$params{'q'}."</a></td></tr>\n";
}
print "</form>\
</table><br/>";

print "<br/><table CLASS=\"head1\" width=\"90%\" border=\"1\" frame=\"border\" align=\"center\">\
<tr><th>patch</th>\
<th>PR#</th>\
<th>PR title</th>\
<th>Change description</th></tr>\n";

my $color=1;
open(DB,$dbfile) or die "$!";
while(<DB>){
  my ($nsmver,$mainver,$pr,$prtitle,$prdesc) = split("\t");
  next if (exists($params{'q'}) and $params{'q'} ne "" and $nsmver!~/$params{'q'}/i);
  next if (exists($params{'prn'}) and $params{'prn'} ne "" and $pr!~/$params{'prn'}/);
  next if (exists($params{'prt'}) and $params{'prt'} ne "" and $prtitle!~/$params{'prt'}/i and $prdesc!~/$params{'prt'}/i);
  if ($color==1){
    print "<tr CLASS=\"row1\">";
    $color=0;
  }else{
    print "<tr CLASS=\"row2\">";
    $color=1;
  }
  print "<td NOWRAP><a href=\"?q=$nsmver&m=1\">$nsmver ($mainver)</a></td><td>";
  if ($pr=~/^\d+\s*$/ and $pr > 0) { 
    print "<a href=\"https://gnats.juniper.net/web/default/$pr\">";
  }
  print "$pr</a></td><td>".$prtitle."</td><td>".$prdesc."</td></tr>\n";
}
close(DB);

print "</table>\n";
if (exists($params{'m'}) and $params{'m'}==1 and exists($params{'q'}) and $params{'q'} ne ""){
  if(open(DIFF,$homedir."/".$params{'q'}."/".$params{'q'}."_filediff")){
    print "<p> File diff for $params{'q'} is displayed bellow.</p><hr/><pre>\n";
    print <DIFF>;
    print "</pre><hr/>\n";
    close(DIFF);  
  } 
}
print "<p align=\"center\"><a href=\"mailto:mlukaszuk\@juniper.net\">complains/ideas</a></p></body></html>\n";


