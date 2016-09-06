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

# version 1.1.2 - cleaned up to support perl -w

require 5.003;
use diagnostics;
use strict;
use vars qw(%opt);
use POSIX qw(fmod);

# Plot satellites on polar azimuthal equidistant map


sub Usage
{
	$0 =~ s/.*\/([^\/]+)$/$1/o;
	print <<EOF;
Usage:  $0 -file name -links -plane -nonum -alpha n -map

Process ns satellite dump output to plot satellite positions on polar map.
Outputs xfig coordinates for use with the background template defined by
coordinate_system.fig

Input file format expected in file "sats.dump" ("Links" is a keyword):
Satnode	Lat(deg)	Long(deg)	Type/Plane#
...
Links:
Lat 	Long	Lat 	Long
...

Type can also be TERM or GEO. Plane# is optional.

Output file format is a series of xfig objects

Options:
	-file name:	Filename of input topology file. Default is sats.dump
	-links:		Place links between the nodes
	-plane:		add polar satellite plane information
	-nonum:		suppress node numbers (on ground terminals if -plane)
	-alpha n:	n satellites per plane; only useful when -plane active
	-map:		draw in azimuthal equidistant background map
	-nomap:		override map switch
EOF
	exit(1);
}

# we can't draw arrowed simplex/duplex links, because:
# 1. xfig doesn't support arrowed arcs directly.
# 2. swapping around endpoints to get the curvature correct would
#    mess up arrowed arcs
# ...but we're still drawing duplex links as two lines on top of each
# other, pending some read-nodes-into-array-and-optimise code

# Generic option-grabbing code
sub Getopt
{
	my($spec) = @_;	# name of variables to be initialized from %opt
	my($key);
	# for use if you want to force arguments
	# &Usage  if ($#ARGV < 0);
	while (defined($ARGV[0]) && ($_ = $ARGV[0], /^-(\w+)/)) {
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

&Getopt("alpha:scale:file:");
my $opt_alpha = $opt{'alpha'}  if (defined($opt{'alpha'}) && (($opt{'alpha'} > 0) && ($opt{'alpha'} < 27)));

my $opt_file = 'sats.dump';
$opt_file = $opt{'file'} if defined($opt{'file'});

my $pi = atan2(1,1)*4;
my @col;

# 6100, 5189 are true center points for north pole. radius is 5000
my $radius = 5000;
my $xcentre = 6100;
my $ycentre = 5189;

if ((defined($opt{'scale'})) && ($opt{'scale'} > 0)) {
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
if (defined($opt{'map'}) && (!defined($opt{'nomap'}))) {
	my $opt_map = 'azeq.gif';
	print "2 5 0 1 0 -1 200 0 -1 0.000 0 0 -1 0 0 5\n";
	printf "	0 %s\n",$opt_map;
	printf "	   %d %d %d %d %d %d %d %d %d %d\n",
	    $xleft,$ytop,$xright,$ytop,$xright,$ybottom,
	    $xleft,$ybottom,$xleft,$ytop;
	printf "4 0 0 100 0 0 9 0.0000 4 1100 %d 1200 %d ", $ybottom-250, $ybottom-150;
	print "Background map rendered by\\001\n";
	printf "4 0 0 100 0 0 9 0.0000 4 1100 %d 1200 %d ",$ybottom-100, $ybottom;
	print "Hans Havlicek (http://www.geometrie.tuwien.ac.at/karto/)\\001\n";

}
print "\n";

open(OUTFILE, $opt_file) or die "$!\n Can't open file ",$opt_file;

my ($num, $srclat, $srclon, $adjlat, $latpoint, $lonpoint, $plane);

while (<OUTFILE>) {
	@col = split;
	if (defined($col[0])) {
		# Make title:  look for line "Dumping satellites at time X"
		if ($col[0] =~ /Dumping/) {
			if (defined($col[4])) {
				print "4 0 0 100 0 0 14 0.0000 4 300 1200 1200 400 ";
				printf "Satellite network at time $col[4]\\001\n";
			}
			next;
		}
		# Loop until we find the keyword "Links:" 
	    last if ($col[0] =~ /Links:/);
		# Filter out text and blank lines - could be better
		next if ($col[0] !~ /[0-9A-Z]+/);
		$num = $col[0];
		if (defined($col[1]) && defined($col[2])) {
			next if ($col[1] !~ /[0-9+-.]+/);
			next if ($col[2] !~ /[0-9+-.]+/);
			$srclat = $col[1];
			$srclon = $col[2];
			# latpoint is xfig y
			# lonpoint is xfig x
			# get latitude into 0 to -180 range.
			$adjlat = ($srclat-90)*$radius/180;
			$latpoint = $ycentre - $adjlat*cos($srclon*$pi/180);
			$lonpoint = $xcentre - $adjlat*sin($srclon*$pi/180);
			if (defined($col[3])) {
				$plane = $col[3];
				if ($plane =~ "TERM") {
					# draw ground terminal
					printf "1 4 0 2 0 7 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
						$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
				} else {
					# draw satellite
					printf "1 4 0 2 7 0 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
						$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
				}
				if ((defined($opt{'plane'}))&&($plane =~ /[0-9]+/)) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f ", $lonpoint+40, $latpoint-75;
					printf "%s",$plane;
					# alphabetics for sats in plane are a hack
					# related node and plane numbering with
					# explicit knowledge of number of sats/plane.
					if (defined($opt{'alpha'})) {
						printf "%s",chr(97+$num-($plane-1)*$opt_alpha);
					}
					printf "\\001\n";
				} elsif (!defined($opt{'nonum'})) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %s", $lonpoint+30, $latpoint-75,$num;
					print "\\001\n";
				}
			} else {
				# default to satellite
				printf "1 4 0 2 7 0 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
					$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
				if (!defined($opt{'nonum'})) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %s", $lonpoint+30, $latpoint-75,$num;
					print "\\001\n";
				}
			}
		}
	}
}


### Print a line for each active ISL 
if (defined($opt{'links'})) {
	my ($a, $lat1, $lat2, $lon1, $lon2, $linktype, $linkcolour, $latmid, $lonmid);
	my ($adjlat1, $adjlat2, $adjlatmid, $latpointmid, $lonpointmid);
	my ($latpoint1, $latpoint2, $lonpoint1, $lonpoint2);
	my ($dx12, $dy12, $dx13, $dy13, $len1, $len2, $len3, $latcentre, $loncentre);
	while (<OUTFILE>) {
		@col = split;
		if (defined($col[0])) {
		    last if ($col[0] =~ /Dumped/);
			next if ($col[0] !~ /[0-9+-.]+/);
			$lat1 = $col[0];
			if ((defined($col[1])) && (defined($col[2])) && (defined($col[3]))) {
				next if ($col[1] !~ /[0-9+-.]+/);
				next if ($col[2] !~ /[0-9+-.]+/);
				next if ($col[3] !~ /[0-9+-.]+/);
				# set link colours
				# default other colour
				$linkcolour = 5;
				if (defined($col[4])) {
					$linktype = $col[4];
					# intraplane
					if ($linktype == "6") {
						$linkcolour = 0; #0 or 4
					}
					# interplane
					if ($linktype == "7") {
						$linkcolour = 1;
					}
					# crosseam
					if ($linktype == "8") {
						$linkcolour = 4;
					}
					# assume remainder are GSLs - this is crude
					if (($linktype > 1) && ($linktype < 6)) {
						$linkcolour = 15;
					}
				}
				$lon1 = $col[1];
				$lat2 = $col[2];
				$lon2 = $col[3];
				# trap boundary problems
				if ($lon1 == -180) {
					$lon1 = -179.9;
				}
				if ($lon1 == 0) {
					$lon1 = 0.1;
				}
				if ($lon2 == -180) {
					$lon2 = -179.9;
				}
				if ($lon2 == 0) {
					$lon2 = 0.1;
				}
				$latmid = ($lat1+$lat2)/2;
				$lonmid = ($lon1+$lon2)/2;

				# need to handle ordering. Go clockwise:
				# lon1 - lonmid - lon2
				#        centre.
				# and compensate for -179 to 0.01 degrees wrap discontinuity.
				if ($lon1 < $lon2) {
					$a = $lon1;
					$lon1 = $lon2;
					$lon2 = $a;
					$a = $lat1;
					$lat1 = $lat2;
					$lat2 = $a;
				}
				if (($lon2+180)+(180-$lon1) < abs($lon1-$lon2)) {
					$a = $lon1;
					$lon1 = $lon2;
					$lon2 = $a;
					$a = $lat1;
					$lat1 = $lat2;
					$lat2 = $a;
				}
				$adjlat1 = ($lat1 - 90)*$radius/180;
				$adjlat2 = ($lat2 - 90)*$radius/180;
				$adjlatmid = ($latmid - 90)*$radius/180;
				$latpointmid = $ycentre - $adjlatmid*cos($lonmid*$pi/180);
				$lonpointmid = $xcentre - $adjlatmid*sin($lonmid*$pi/180);

				$latpoint1 = $ycentre - $adjlat1*cos($lon1*$pi/180);
				$lonpoint1 = $xcentre - $adjlat1*sin($lon1*$pi/180);
				$latpoint2 = $ycentre - $adjlat2*cos($lon2*$pi/180);
				$lonpoint2 = $xcentre - $adjlat2*sin($lon2*$pi/180);
		
				# took this from xfig's u_geom.c compute_arccenter()
				$dy12 = $latpoint1 - $latpointmid;
				$dx12 = $lonpoint1 - $lonpointmid;
				$dy13 = $latpoint1 - $latpoint2;
				$dx13 = $lonpoint1 - $lonpoint2;

				if (abs(($dx13 * $dy12) - ($dx12 * $dy13))<0.01 ) {
					# draw straight line when circle would be infinitely big
					printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 0 0 2\n",
						$linkcolour;
					printf "         %.0f %.0f %.0f %.0f\n", 
						$lonpoint1, $latpoint1, $lonpoint2, $latpoint2;
				} else {
					$len1 = $latpoint1*$latpoint1 + $lonpoint1*$lonpoint1;
					$len2 = $latpointmid*$latpointmid + $lonpointmid*$lonpointmid;
					$len3 = $latpoint2*$latpoint2 + $lonpoint2*$lonpoint2;
					$latcentre = ($dx12 * ($len3 - $len1) - $dx13 * ($len2 - $len1))/(2 * (($dx13 * $dy12) - ($dx12 * $dy13)));
					$loncentre = ($len3 + 2 * ($latcentre) * $dy13 - $len1) / (2 * (-$dx13));
					if ($lonpoint1 == $lonpoint2) {
						$loncentre = ($len2 + 2 * ($latcentre) * $dy12 - $len1) / (2 * (-$dx12));
					}

					# draw arc
					printf "5 1 0 2 %d 7 100 0 -1 0.000 0 0 0 0 %.3f %.3f %.0f %.0f %.0f %.0f %.0f %.0f\n",
						$linkcolour,
						$loncentre, $latcentre,
						$lonpoint1, $latpoint1, 
						$lonpointmid, $latpointmid,
						$lonpoint2, $latpoint2;
				}
			}
		}
	}
}
exit(1);
1;
