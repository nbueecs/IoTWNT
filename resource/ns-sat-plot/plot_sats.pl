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

# Plot satellites on unprojected map

# version 1.1.2 - cleaned up to support perl -w

sub Usage
{
	$0 =~ s/.*\/([^\/]+)$/$1/o;
	print <<EOF;
Usage:  $0 -file name -links -arrows -plane -nonum -alpha n -map name -scale n

Process ns satellite dump output to plot satellite positions on a map.
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
	-file name:     Filename of input topology file. Default is sats.dump
	-links:		Place links between the nodes
	-arrows:	Label links with directed arrows
	-plane:		add polar satellite plane information
	-nonum:		suppress node numbering (on ground terminals if also -plane)
	-alpha n:	n satellites per plane; only useful when -plane active
	-map name:	Add background mapfile (1,2,3,4 select available gifs)	
	-scale n:	number of xfig units to the degree
	-nomap:         override map switch
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


&Getopt("alpha:map:scale:file:");
my $opt_alpha = $opt{'alpha'}  if ((defined($opt{'alpha'})) && ($opt{'alpha'} > 0) && ($opt{'alpha'} < 27));

my $opt_scale = 30; # xfig units to the degree

if ((defined($opt{'scale'})) && ($opt{'scale'} > 0)) {
	$opt_scale = $opt{'scale'};
}

my $opt_file = 'sats.dump';
$opt_file = $opt{'file'} if (defined($opt{'file'}));

my @col;

# 3900, 6600 are true center points for grid. 1200, 1200 is top left corner.
my $scale = $opt_scale;
my $xcentre = 1200 + 180*$scale;
my $ycentre = 1200 + 90*$scale;

my $xwest = $xcentre - ($scale*180);
my $xeast = $xcentre + ($scale*180);
my $ynorth = $ycentre - ($scale*90);
my $ysouth = $ycentre + ($scale*90);

print "\n";

my $opt_map = "1"; # choose default map if no value given
if ((!defined($opt{'nomap'})) && (defined($opt{'map'})) && ($opt{'map'} =~ /[a-zA-Z0-9]+/)) {
	# handle -map by itself if followed by a switch
	$opt_map = $opt{'map'} if ($opt{'map'} !~ /^-/);
	$opt_map .= '.gif' if ($opt_map !~ /\./);
	print "-6\n";
	print "2 5 0 1 0 -1 103 0 -1 0.000 0 0 -1 0 0 5\n";
	printf "	0 %s\n",$opt_map;
	printf "	   %d %d %d %d %d %d %d %d %d %d\n",
	    $xwest,$ynorth,$xeast,$ynorth,$xeast,$ysouth,
	    $xwest,$ysouth,$xwest,$ynorth;
}
print "\n";

open(OUTFILE, $opt_file) or die "$!\n Can't open file ",$opt_file;

my ($num,$srclat,$srclon,$srcaltitude,$latpoint,$lonpoint,$plane);
my ($lat1,$lat2,$lon1,$lon2,$latpoint1,$latpoint2,$lonpoint1,$lonpoint2,$diff_lon);
my ($linktype,$linkcolour);
my ($x1,$x2,$y1,$y2,$den,$numer,$new_latpoint,$new_lonpoint);

while (<OUTFILE>) {
	@col = split;
	# Make title:  look for line "Dumping satellites at time X"
	if (defined($col[0])) {
		if ($col[0] =~ /Dumping/) {
			if (defined($col[4])) {
				print "4 0 0 100 0 0 14 0.0000 4 165 7500 1200 825 ";
				printf "Satellite network at time $col[4]\\001\n";
			}
			next;
		}
	
		# Loop until we find the keyword "Links:" 
	    last if ($col[0] =~ /Links:/);
		# Filter out text and blank lines
		# this doesn't work that well...
		next if ($col[0] !~ /[0-9A-Z]+/);
		$num = $col[0];
		if ((defined($col[1])) && (defined($col[2]))) {
			next if ($col[1] !~ /[0-9+-.]+/);
			$srclat = $col[1];
			next if ($col[2] !~ /[0-9+-.]+/);
			$srclon = $col[2];
			$latpoint = $ycentre - $scale * $srclat;
			$lonpoint = $xcentre + $scale * $srclon;
			if (defined($col[3]))  {
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
				if ((defined($opt{'plane'})) && ($plane =~ /[0-9]+/)) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f ",
						$lonpoint+40, $latpoint-75;
					printf "%s",$plane;
					# alphabetics for sats in plane are a hack
					# related node and plane numbering with
					# explicit user knowledge of number of sats/plane.
					if (defined($opt{'alpha'})) {
						printf "%s",chr(97+$num-($plane-1)*$opt_alpha);
					}
					print "\\001\n";
				} elsif (!defined($opt{'nonum'})) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %s",
						$lonpoint+30, $latpoint-75,$num;
					print "\\001\n";
				}
			} else {
				# default to satellite
				printf "1 4 0 2 7 0 10 0 20 0.000 1 0.0000 %.0f %.0f 50 50 %.0f %.0f %.0f %.0f\n",
					$lonpoint,$latpoint,$lonpoint+50,$latpoint,$lonpoint,$latpoint;
				if (!defined($opt{'nonum'})) {
					printf "4 0 0 100 0 2 11 0.0000 4 90 90 %.0f %.0f %s",
						$lonpoint+30, $latpoint-75,$num;
					print "\\001\n";
				}
			}
		}
	}
}
### Print a line for each active ISL 
if (defined($opt{'links'})) {
	while (<OUTFILE>) {
		@col = split;
		if (defined($col[0])) {
		    last if ($col[0] =~ /Dumped/);
			next if ($col[1] !~ /[0-9+-.]+/);
			$lat1 = $col[0];
			if (defined($col[1]) && defined($col[2]) && defined($col[3])) {
				next if ($col[1] !~ /[0-9+-.]+/);
				next if ($col[2] !~ /[0-9+-.]+/);
				next if ($col[3] !~ /[0-9+-.]+/);
				$lon1 = $col[1];
				$lat2 = $col[2];
				$lon2 = $col[3];
					
				# default other colour
				$linkcolour = 5;
				if (defined($col[4])) {
					$linktype = $col[4];
					# intraplane
					if ($linktype == "6") {
						$linkcolour = 0;
					}
					# interplane
					if ($linktype == "7") {
						$linkcolour = 1;
					}
					# crossseam
					if ($linktype == "8") {
						$linkcolour = 4;
					}
					# assume remainder are GSLs - this is crude
					if (($linktype > 1) && ($linktype < 6)) {
						$linkcolour = 15;
					}
				}
			
				$lonpoint1 = $xcentre + $scale * $lon1;
				$latpoint1 = $ycentre - $scale * $lat1;
				$lonpoint2 = $xcentre + $scale * $lon2;
				$latpoint2 = $ycentre - $scale * $lat2;
				$diff_lon = $lon1 - $lon2;

				if ($diff_lon > -180 && $diff_lon < 180) {
					if (defined($opt{'arrows'})) {
						printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 1 0 2\n",
							$linkcolour;
						print "        1 1 1.00 60.00 120.00\n";
						printf "         %.0f %.0f %.0f %.0f\n", 
							$lonpoint1, $latpoint1, $lonpoint2, $latpoint2;
					} else {
						printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 0 0 2\n",$linkcolour;
						printf "         %.0f %.0f %.0f %.0f\n",
								$lonpoint1, $latpoint1, $lonpoint2, $latpoint2;
					}
				} else {
					### The following kludgy code handles the
					### case when lines go off the vertical edge
					if ($diff_lon < -180) {
						$y1 = $lon1;
						$x1 = $lat1;
						$y2 = $lon2;
						$x2 = $lat2;
						$new_lonpoint = $xwest;
					} else {
						$y2 = $lon1;
						$x2 = $lat1;
						$y1 = $lon2;
						$x1 = $lat2;
						$new_lonpoint = $xeast; 
					}
					$den = 360 + $y1 - $y2;
					$numer = (180 + $y1) * ($x1 - $x2);
					$new_latpoint = $ycentre - $scale * ($x1 - $numer/$den);
					printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 0 0 2\n",$linkcolour;
					printf "         %.0f %.0f %.0f %.0f\n",
						$new_lonpoint, $new_latpoint,
						$lonpoint1, $latpoint1;
					### Other half of line
					if ($diff_lon < -180) {
						$new_lonpoint = $xeast;
					} else {
						$new_lonpoint = $xwest;
					}
					if (defined($opt{'arrows'})) {
						printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 1 0 2\n",
							$linkcolour;
						print "        1 1 1.00 60.00 120.00\n";
						printf "         %.0f %.0f %.0f %.0f\n",
				 	   		$new_lonpoint, $new_latpoint,
				 	   		$lonpoint2, $latpoint2;
					} else {
						printf "2 1 0 2 %d 7 100 0 -1 0.000 0 0 -1 0 0 2\n",
							$linkcolour;
						printf "         %.0f %.0f %.0f %.0f\n",
				  	  		$new_lonpoint, $new_latpoint,
				   	 		$lonpoint2, $latpoint2;
					}
				}
			}
		}
	}
}
exit(1);
1;
