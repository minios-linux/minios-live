#!/usr/bin/perl

sub create_patches {
    my $tag=shift;
    my $pdir=shift;
    my $n=1;
    my @lines;
    my $fname;
    my $f=0;

    mkdir $pdir, 0755;

    open( GIT, 'git log -p --pretty=email --stat -m --first-parent --reverse --binary '.$tag.'..HEAD |');

    while (<GIT>) {
        if (/^From [a-z0-9]{40} .*$/) {
            $fname = sprintf("%04d", $n++).".patch";
            open FH, ">".$pdir."/".$fname;
            $f=1;
        }
        if (/^---$/ && $f == 1) {
            push @lines, $fname;
            $f=0;
        }
        print FH;
    }

    return @lines;
};

use POSIX qw(strftime);
my $datestr = strftime "%Y%m%d", gmtime;

my $tag=shift;
my $pdir=shift;
$tag=`git describe --abbrev=0 --tags` if not defined $tag;
chomp($tag);
my @patches=&create_patches($tag, $pdir);
my $num=$#patches + 2;
$tag=~s/[^0-9]+?([0-9]+)/$1/ if $tag !~ /\b[0-9a-f]{5,40}\b/;
my $release="$num.git$datestr";
$release="1" if $num == 1;

while(<>) {
    if (/^Version:/) {
	print "Version: $tag\n";
    }
    elsif (/^%define dist_free_release/) {
	print "%define dist_free_release $release\n";
    }
    elsif ((/^Source0:/) || (/^Source:/)) {
	print $_;
	$num=1;
	for(@patches) {
	    s/.*\///g;
	    print "Patch$num: $_\n";
	    $num++;
	}
	print "\n";
    }
    else {
	print $_;
    }
}
