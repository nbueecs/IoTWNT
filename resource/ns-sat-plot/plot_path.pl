#!/usr/local/bin/perl

# Copyright (c) 1999, 2000 Regents of the University of California.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#       This product includes software developed by the MASH Research
#       Group at the University of California Berkeley.
# 4. Neither the name of the University nor of the Research Group may be
#    used to endorse or promote products derived from this software without
#    specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.    

require 5.003;
use diagnostics;
use strict;
use vars qw(%opt);

# Process ns satellite trace output to plot packet paths on a map 
# Run "plot_path.pl -help" for help

# version 1.1 - cleaned up to support perl -w

sub Usage
{
	$0 =~ s/.*\/([^\/]+)$/$1/o;
	print <<EOF;
Usage:  $0 -file name -links -hopcount -packet n -map name -scale n

Process ns satellite trace output to plot packet paths on a map.
Outputs xfig coordinates for use with the background defined by
coordinate_system.fig

Options:  
	-file:	    Filename of input satellite tracefile. Default is plot.tr
	-links:     Place links between the nodes 
	-hopcount:  Label satellite by hop number rather than node number
	-packet n:  Print only the packet number n
	-map name:  Add background mapfile (1,2,3,4 select available gifs).
	-scale n:   number of xfig units to the degree
	-nomap:	    override map switch
EOF
	exit(1);
}


# Generic option-grabbing code
sub Getopt
{
	my($spec) = @_;	# name of variables to be initialized from %opt
	my($key);
	# for use if you want to force arguments 
	# &Usage  if ($#ARGV < 0);
	while ((defined($ARGV[0])) && ($_ = $ARGV[0], /^-(\w+)/)) {
		shift @ARGV;
		$key = $1;
		if ($key eq "help") {
			&Usage;
		} else {
			$opt{$key} = (index($spec, "$key:") >= 0) ? 
			    shift @ARGV : 1;
		}
	}
}

&Getopt("packet:map:scale:file:");

my $opt_packet = $opt{'packet'}  if ((defined($opt{'packet'})) && ($opt{'packet'} >= 0));
my $opt_links = $opt{'links'} if (defined($opt{'links'}));
my $opt_hopcount = $opt{'hopcount'} if (defined($opt{'hopcount'}));

my $opt_scale = 30; # xfig units to the degree
$opt_scale = $opt{'scale'} if ((defined($opt{'scale'})) && ($opt{'scale'} > 0));

my $opt_file = "plot.tr";
$opt_file = $opt{'file'} if ((defined($opt{'file'})) && $opt{'file'});

my (@col, @co);

# 3900, 6600 are true centre points for grid. 1200, 1200 is top left corner.
my $scale = $opt_scale;
my $xcentre = 1200 + 180*$scale;
my $ycentre = 1200 + 90*$scale;

my $xwest = $xcentre - ($scale*180);
my $xeast = $xcentre + ($scale*180);
my $ynorth = $ycentre - ($scale*90);
my $ysouth = $ycentre + ($scale*90);


if ((defined($opt{'map'})) && (!defined($opt{'nomap'})) && ($opt{'map'} =~ /[a-zA-Z0-9]+/)) {
	my $opt_map = "1"; # choose default map if no value given
	$opt_map = $opt{'map'};
	$opt_map .= '.gif' if ($opt_map !~ /\./);
	print "-6\n";
	print "2 5 0 1 0 -1 103 0 -1 0.000 0 0 -1 0 0 5\n";
	printf "        0 %s\n",$opt_map;
	printf "           %d %d %d %d %d %d %d %d %d %d\n",
	    $xwest,$ynorth,$xeast,$ynorth,$xeast,$ysouth,$xwest,$ysouth,$xwest,$ynorth;
}
print "\n";

open(OUTFILE, $opt_file) or die "$!\n Can't open file ",$opt_file;

my $packetnum = 1;
my ($den, $dest, $destnode, $num, $print_this_packet);
my ($srclat, $srclon, $latpoint, $lonpoint);
my ($prev_latpoint,$prev_lonpoint,$prev_srclat,$prev_srclon,$recvnode);
my ($x1, $x2, $y1, $y2, $numer, $dstlat, $dstlon, $found, $nodenum);
my ($new_lonpoint, $new_latpoint, $diff_lon);

my ($sent, $recv, $elapsed);

while (<OUTFILE>) {
	### Pull fields out of a line (col[0], col[1], etc.)
	@col = split;
	if ((!defined($col[0])) || ($col[0] eq "d") || (!defined($col[13]))) {
		next; # packet drop; skip to next line
	}
	# $sent is not currently used
	$sent = $col[1];	
	### dest is a node.port number, like "67.0"
	$dest = $col[9];
	$packetnum = $col[10];
	### pull out node portion of number
	### NOTE:  =~ is a binding of $dest to the search
	if ($dest =~ /([0-9]+).([0-9]+)/) {
		$destnode = $1;
	}
	### get latitude and longitude of source satellite (or earth terminal)
	$num = 0;
	# packet num should be uid of packet
	$packetnum = $col[10];
	$srclat = $col[12];
	$srclon = $col[13];
	$latpoint = $ycentre - $scale * $srclat;
	$lonpoint = $xcentre + $scale * $srclon;
	$print_this_packet = (!$opt_packet || $packetnum == $opt_packet);
	### Print "S" for source of packet
	if ($print_this_packet) {
		printf "1 4 0 2 7 5 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
			$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
		printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f S\\001\n",
			$lonpoint+60, $latpoint+175;
	}
	### skip two lines - this assumes a lot.
	$_ = <OUTFILE>; # 1st hop deque
	$_ = <OUTFILE>; # 1st hop recv 
	$_ = <OUTFILE>; # 2nd hop enque or drop 
	@co = split;
	if ($co[0] ne "d") {
		$_ = <OUTFILE>; # deque (2nd hop deque)
		$_ = <OUTFILE>; # recv or drop (TTL)
	}
	$found = 0;
	### Need to find the line in which the packet is received by the dest.
	while ($found == 0 && $_) {
		$prev_latpoint = $latpoint;
		$prev_lonpoint = $lonpoint;
		$prev_srclat = $srclat;
		$prev_srclon = $srclon;
		@co = split;
		$recv = $co[1];
		$recvnode = $co[3];
		$num += 1;
		$srclat = $co[12];
		$srclon = $co[13];
		$latpoint = $ycentre - $scale * $srclat;
		$lonpoint = $xcentre + $scale * $srclon;
		### lonpoint and latpoint are adjusted for text offset
		if ($print_this_packet) {
		if ($opt_hopcount) {
			$nodenum = $num;
		} else {
			$nodenum = $co[2];
		}
	 	printf "1 4 0 2 5 7 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
	 		$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
		printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %d\\001\n",
			$lonpoint+60, $latpoint+175, $nodenum;
		}
		if ($opt_links && $print_this_packet) {
			### Print a line between two satellites
			$diff_lon = $prev_srclon - $srclon;
			if ($diff_lon > -270 && $diff_lon < 270) {
				print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n", 
				    $lonpoint, $latpoint, $prev_lonpoint, 
			            $prev_latpoint;
			} else {
				### The following kludgy code handles the
				### case when lines go off the vertical edge
				if ($diff_lon < -270) {
					$y1 = $prev_srclon;
					$x1 = $prev_srclat;
					$y2 = $srclon;
					$x2 = $srclat;
					$new_lonpoint = $xwest;
				} else {
					$y2 = $prev_srclon;
					$x2 = $prev_srclat;
					$y1 = $srclon;
					$x1 = $srclat;
					$new_lonpoint = $xeast;
				}
				$den = 360 + $y1 - $y2;
				$numer = (180 + $y1) * ($x1 - $x2);
				$new_latpoint = $ycentre - $scale * ($x1 - $numer/$den);
			 	print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n",
				    $new_lonpoint, $new_latpoint, 
				    $prev_lonpoint, $prev_latpoint;
				### Other half of line
				if ($diff_lon < -270) {
					$new_lonpoint = $xeast;
				} else {
					$new_lonpoint = $xwest;
				}
			 	print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n",
				    $new_lonpoint, $new_latpoint, 
				    $lonpoint, $latpoint;
			}
		}
		if ($destnode == $recvnode || $co[0] eq "d") {
			$prev_latpoint = $latpoint;
			$prev_lonpoint = $lonpoint;
		        $elapsed = ($recv - $sent) * 1000;
			$found = 1;
			$dstlat = $co[14];
			$dstlon = $co[15];
			$latpoint = $ycentre - $scale * $dstlat;
			$lonpoint = $xcentre + $scale * $dstlon;
			if ($print_this_packet) {
			if ($co[0] eq "d") {
			if ($opt_hopcount) {
				$nodenum = $num;
			} else {
				$nodenum = $co[2];
			}
				printf "1 4 0 2 7 5 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
					$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
		 		printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %d\\001\n",
		 			$lonpoint+60, $latpoint+175, $nodenum;
			} else {
				### Print "D" for destination of packet
				printf "1 4 0 2 7 5 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
					$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
				printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f D\\001\n",
					$lonpoint+60, $latpoint+175;
				print "4 0 0 100 0 0 14 0.0000 4 4000 7500 8000 825 ";
				printf "Packet seen from $sent to $recv duration $elapsed ms\\001\n";
			}
			}
			if ($opt_links && $print_this_packet) {
				$diff_lon = $srclon - $dstlon;
				if ($diff_lon > -270 && $diff_lon < 270) {
					### Print a line between two satellites
					print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
					printf "         %.0f %.0f %.0f %.0f\n",
					    $lonpoint, $latpoint, 
					    $prev_lonpoint, $prev_latpoint;
				} else {
				### The following kludgy code handles the
				### case when lines go off the vertical edge
				if ($diff_lon < -270) {
					$y1 = $srclon;
					$x1 = $srclat;
					$y2 = $dstlon;
					$x2 = $dstlat;
					$new_lonpoint = $xwest;
				} else {
					$y2 = $srclon;
					$x2 = $srclat;
					$y1 = $dstlon;
					$x1 = $dstlat;
					$new_lonpoint = $xeast;
				}
				$den = 360 + $y1 - $y2;
				$numer = (180 + $y1) * ($x1 - $x2);
				$new_latpoint = $ycentre - $scale * ($x1 - $numer/$den);
			 	print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n",
				    $new_lonpoint, $new_latpoint, 
				    $prev_lonpoint, $prev_latpoint;
				### Other half of line
				if ($diff_lon < -270) {
					$new_lonpoint = $xeast;
				} else {
					$new_lonpoint = $xwest;
				}
			 	print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n",
				    $new_lonpoint, $new_latpoint, 
				    $lonpoint, $latpoint;
				}
			}
		} else {
			$_ = <OUTFILE>; # enque or drop
			@co = split;
			if ($co[0] ne "d") {
				$_ = <OUTFILE>; # deque 
				$_ = <OUTFILE>; # recv or drop (TTL)
			}
		} 
	}
	$packetnum += 1;
	if ($print_this_packet) {
		last;
	}
}
exit(1);
1;
