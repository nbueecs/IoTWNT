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

# Polar plots by Lloyd Wood, from Tom Henderson's plot code and xfig source.

# version 1.1 - cleaned up to support perl -w

require 5.003;
use diagnostics;
use strict;
use vars qw(%opt);
use POSIX qw(fmod);

# Plot packet path on polar azimuthal equidistant map


sub Usage
{
	$0 =~ s/.*\/([^\/]+)$/$1/o;
	print <<EOF;
Usage:  $0 -file name -packet n -hopcount -links -map

Process ns satellite tracefile to plot packet path on polar map.
Outputs xfig coordinates for use with the background template defined by
coordinate_system.fig

Input file format expected in file "plot.tr" ("Links" is a keyword):
Satnode	Lat(deg)	Long(deg)	Type/Plane#
...
Links:
Lat 	Long	Lat 	Long
...

Type can also be TERM or GEO. Plane# is optional.

Output file format is a series of xfig objects

Options:
	-file name:	Filename of input topology file. Default is plot.tr
	-packet n:	Print only the packet number n
	-hopcount:	Label satellite by hop number rather than node number
	-links:		Place links between the nodes
	-map:           draw in azimuthal equidistant background map
	-nomap:		override map switch

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

sub asin
{
	atan2($_[0], sqrt(1- $_[0] * $_[0]))
}

&Getopt("packet:scale:file:");

my $opt_packet = $opt{'packet'} if ((defined($opt{'packet'})) && ($opt{'packet'} >= 0));
my $opt_links = $opt{'links'} if (defined($opt{'links'}));
my $opt_hopcount = $opt{'hopcount'} if (defined($opt{'hopcount'}));

my $opt_file = 'plot.tr';
$opt_file = $opt{'file'} if (defined($opt{'file'}));

my $pi = atan2(1,1)*4;
my (@col, @co);

# 6100, 5189 are true center points for north pole. radius is 5000
my $radius = 5000;
my $xcentre = 6100;
my $ycentre = 5189;

if (defined($opt{'scale'})) {
	my $opt_scale = $opt{'scale'};
	$radius = 180*$opt_scale;
	$xcentre = 200+$radius;
	$ycentre = 200+$radius;
}

# you could rotate the background by swapping these around -
# but then it won't match the coordinates and plot!
my $xright = $xcentre + $radius;
my $xleft = $xcentre - $radius;
my $ybottom = $ycentre + $radius;
my $ytop = $ycentre - $radius;

print "\n";
if ((defined($opt{'map'})) && (!defined($opt{'nomap'}))) {
	my $opt_map = 'azeq.gif';
	printf "2 5 0 1 0 -1 200 0 -1 0.000 0 0 -1 0 0 5\n";
	printf "	0 %s\n",$opt_map;
	printf "	   %d %d %d %d %d %d %d %d %d %d\n",
	    $xleft,$ytop,$xright,$ytop,$xright,$ybottom,
	    $xleft,$ybottom,$xleft,$ytop;
	printf "4 0 0 100 0 0 9 0.0000 4 1100 %d 1200 %d ", $ybottom-250, $ybottom-150;
	print "Background map rendered by\\001\n";
	printf "4 0 0 100 0 0 9 0.0000 4 1100 %d 1200 %d ",$ybottom-100, $ybottom;
	print "Hans Havlicek (http://www.geometrie.tuwien.ac.at/karto/)\\001\n";
}

open(OUTFILE, $opt_file) or die "$!\n Can't open file ",$opt_file;

my $packetnum = 1;

my ($den, $dest, $destnode, $recvnode, $num, $print_this_packet);
my ($srclat, $srclon, $latpoint, $lonpoint);
my ($prev_latpoint, $prev_lonpoint);
my ($prev_srclat, $prev_srclon);
my ($adjlat, $dstlat, $dstlon, $found, $nodenum);
my ($sent, $recv, $elapsed);


while (<OUTFILE>) {
	### Pull fields out of a line (col[0], col[1], etc.)
	@col = split;
	if ((!defined($col[0])) || ($col[0] eq "d") || (!defined($col[13])) ) {
		next; # packet drop; skip to next line
	}
	$sent = $col[1];	
	### dest is a node.port number, like "67.0"
	$dest = $col[9];
	### pull out node portion of number
	### NOTE:  =~ is a binding of $dest to the search
	if ($dest =~ /([0-9]+).([0-9]+)/) {
		$destnode = $1;
	}
	### get latitude and longitude of source satellite (or earth terminal)
	$num = 0;
	# packet num should be uid of packet
	$packetnum = $col[10];
	$print_this_packet = (!$opt_packet || $packetnum == $opt_packet);
	$srclat = $col[12];
	$srclon = $col[13];
	# get latitude into the 0 to -180 range.
	$adjlat = ($srclat-90)*$radius/180;
	$latpoint = $ycentre - $adjlat*cos($srclon*$pi/180);
	$lonpoint = $xcentre - $adjlat*sin($srclon*$pi/180);
	
	### Print "S" for source of packet
	if ($print_this_packet) {
		printf "1 4 0 2 7 5 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
			$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
		printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f S\\001\n",
			$lonpoint+60, $latpoint;
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
		$adjlat = ($srclat-90)*$radius/180;
		$latpoint = $ycentre - $adjlat*cos($srclon*$pi/180);
		$lonpoint = $xcentre - $adjlat*sin($srclon*$pi/180);
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
			print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
			printf "         %.0f %.0f %.0f %.0f\n", 
				$lonpoint, $latpoint, $prev_lonpoint, 
				$prev_latpoint;
		}

		if ($destnode == $recvnode || $co[0] eq "d") {
			$prev_latpoint = $latpoint;
			$prev_lonpoint = $lonpoint;
			$elapsed = ($recv - $sent) * 1000;
			$found = 1;
			$dstlat = $co[14];
			$dstlon = $co[15];
			$adjlat = ($dstlat-90)*$radius/180;
			$latpoint = $ycentre - $adjlat*cos($dstlon*$pi/180);
			$lonpoint = $xcentre - $adjlat*sin($dstlon*$pi/180);
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
					$lonpoint,$latpoint,$lonpoint-50,$latpoint,$lonpoint,$latpoint;
				printf "\n4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f D\\001\n",
					$lonpoint+60, $latpoint;
				printf "4 0 0 100 0 0 14 0.0000 4 4000 %d 8000 200 ",
					$xcentre*7/12;
				printf "Packet seen from $sent to $recv duration $elapsed ms\\001\n";
			}
			}
			if ($opt_links && $print_this_packet) {
				### Print a line between two satellites
				print "2 1 0 2 5 7 100 0 -1 0.000 0 0 -1 0 0 2\n";
				printf "         %.0f %.0f %.0f %.0f\n",
				    $lonpoint, $latpoint, 
				    $prev_lonpoint, $prev_latpoint;
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
