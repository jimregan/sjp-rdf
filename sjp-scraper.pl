#!/usr/bin/perl

use warnings;
use strict;
use utf8;

use Data::Dumper;
use URI::Escape;
use HTML::Entities;

open (my $fh, ">>/tmp/writer.rdf");
my ($word, $escword);
my $reading = 0;
my $debug = 1;

binmode STDIN, ":encoding(iso-8859-2)";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
binmode $fh, ":utf8";

sub doheader {
	my $out = shift;

	print $out "<?xml version='1.0' encoding='utf-8'?>\n";
	print $out "<rdf:RDF\n";
	print $out "    xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\n";
	print $out "    xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"\n";
	print $out "    xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\"\n";
	print $out "    xmlns:gold=\"http://www.linguistics-ontology.org/bibliography/bibliography.owl#\"\n";
	print $out "    xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n";
	print $out "    xmlns:sioc=\"http://rdfs.org/sioc/ns#\"\n";
	print $out "    xmlns:sjp=\"http://example.com/sjp/\"\n";
	print $out "    xml:lang=\"pl\">\n";
}

sub dofooter {
	my $out = shift;

	print $out "</rdf:RDF>\n";
}

sub dodate {
	my $in = shift;
	my $out;

	if ($in =~ /([0-9][0-9][0-9][0-9])-([0-9][0-9])-([0-9][0-9]) ([0-9][0-9]):([0-9][0-9])/) {
		$out = "$1-$2-$3T$4:$5";
	} else {
		$out = $in;
	}
	return $out;
}

sub myescape {
	my $in = shift;

	$in =~ s/ /\+/g;
	$in =~ s/Ą/%A1/g;
	$in =~ s/ą/%B1/g;
	$in =~ s/Ć/%C6/g;
	$in =~ s/ć/%E6/g;
	$in =~ s/Ż/%AF/g;
	$in =~ s/ż/%BF/g;
	$in =~ s/Ź/%AC/g;
	$in =~ s/ź/%BC/g;
	$in =~ s/Ś/%A6/g;
	$in =~ s/ś/%B6/g;
	$in =~ s/Ę/%CA/g;
	$in =~ s/ę/%EA/g;
	$in =~ s/Ł/%A3/g;
	$in =~ s/ł/%B3/g;
	$in =~ s/Á/%C1/g;
	$in =~ s/á/%E1/g;
	$in =~ s/É/%C9/g;
	$in =~ s/é/%E9/g;
	$in =~ s/Ó/%D3/g;
	$in =~ s/ó/%F3/g;
	$in =~ s/Í/%CD/g;
	$in =~ s/í/%ED/g;
	$in =~ s/Ú/%DA/g;
	$in =~ s/ú/%FA/g;

	return $in;
}

sub procinner {
	my $in = shift;
	my $out = shift;

	my $odm = 0;
	my ($haslo, $eschaslo, $num);
	my ($datazm, $osobazm);

	my @meanings = ();
	my $meaningtext = "";

	while(<$in>) {
		chomp;
		if (m!<h1 style="font-family: Verdana, sans-serif;">([^<]*)</h1>!) {
			print STDERR "-> $_ : word: $1\n" if ($debug);
			$word = $1;
			$escword = myescape($word);
			print $out "  <sjp:haslo rdf:about=\"http://www.sjp.pl/co/$escword\" rdfs:label=\"$word\"/>\n";
		}

		if (defined $word) {
			if (m!<div class="wf">!) {
				$reading = 1;
			}
			if($reading == 1 && m!</table>!) {
				$reading = 0;
				$odm = 0;
   				print $out "  </sjp:forma>\n";
				if ($meaningtext ne "") {
					print $out $meaningtext;
					$meaningtext = "";
				}
			}

			if (m!<div class="v" style="float: right; color: #68b;">([^,]*), <span style="font-size: x-small;">([^<]*)</span></div>!i) {
				print STDERR "os. -> $1, dat. $2 \n" if ($debug);
				$osobazm = "$1";
				$datazm = dodate($2);
			} 
			if (m!<b>([0-9]*)\. ([^<]*)</b>!i) {
				print STDERR "-> $_ : $2 : $1\n" if ($debug);
				$haslo = "$2";
				$num = $1;
				if ($haslo ne $word) {
					print $out "  <!-- word: $word; entry: $haslo -->\n";
				}
				$eschaslo = myescape($haslo);
   				print $out "  <sjp:forma rdf:about=\"http://www.sjp.pl/co/$eschaslo#$num\">\n";
   				print $out "    <rdfs:label>$haslo</rdfs:label>\n";
				print $out "    <rdfs:seeAlso rdf:resource=\"http://www.sjp.pl/co/$escword\"/>\n";
				if ($osobazm) {
					print $out "    <sioc:has_moderator>$osobazm</sioc:has_moderator>\n";
				}
				if ($datazm) {
					print $out "    <sioc:last_activity_date rdf:datatype=\"xsd:dateTime\">$datazm</sioc:last_activity_date>\n";
				}
			}
			if (m!<b>($word)</b>!i) {
				print STDERR "has. -> $_ : $1\n" if ($debug);
				$haslo = "$1";
				$eschaslo = uri_escape_utf8($haslo);
			}

			if (m!<tr><th scope="row" nowrap="nowrap">dopuszczalność w grach:</th><td>(tak|nie)</td></tr>!i) {
				print STDERR "dop. -> $_ : $1\n" if ($debug);
				if ($1 eq "tak") {
					print $out "    <sjp:dopuszczalnosc rdf:datatype=\"xsd:Boolean\">true</sjp:dopuszczalnosc>\n";
				} else {
					print $out "    <sjp:dopuszczalnosc rdf:datatype=\"xsd:Boolean\">false</sjp:dopuszczalnosc>\n";
				}
			}
			if (m!<tr><th scope="row" width="30%" valign="top">znaczenie:</th><td>([^<]*)<br />!i) {
				print STDERR "znacz. -> $_ : $1\n" if ($debug);
				my $znacz = $1;
				if ($znacz eq "brak") {
					# do nothing
				} else {
					print $out "    <rdfs:comment>$znacz</rdfs:comment>\n";
					@meanings = split_defs($znacz);
					for (my $i = 0; $i < $#meanings+1; $i++) {
						my $nodeid = "h-$escword-$num-" . ($i + 1);
						$nodeid =~ s/\%//g;
						$nodeid =~ s/\+/-/g;
						#$meanings[$i] =~ s/\;$//;
						print $out "    <rdfs:seeAlso rdf:nodeID=\"$nodeid\"/>\n";
						$meaningtext .= "  <sjp:definition rdf:ID=\"$nodeid\">$meanings[$i]</sjp:definition>\n";
					}
				}
			}

			if (m!<tr><th scope="row" valign="top">występowanie:</th><td>([^<]*)</td></tr>!) {
				print STDERR "wys. -> $_ : citation\n" if ($debug);
				my $cite = decode_entities($1);
				print $out "    <sjp:wystepowanie>$cite</sjp:wystepowanie>\n";
			}
			if (m!<tr><th scope="row">odmienność:</th><td>(tak|nie)</td></tr>!i) {
				print STDERR "odm. -> $_ : $1\n" if ($debug);
				if ($1 eq "tak") {
					$odm = 1;
					print $out "    <sjp:odmiennosc rdf:datatype=\"xsd:Boolean\">true</sjp:odmiennosc>\n";
				} else {
					$odm = 0;
					print $out "    <sjp:odmiennosc rdf:datatype=\"xsd:Boolean\">false</sjp:odmiennosc>\n";
				}
			}
			if ($odm == 1 && m!<tr><th scope="row" valign="top"><tt>([^<]*)</tt></th><td>([^<]*)</td></tr>!) {
				print STDERR "1: $1: 2: $2\n";
				my $flaga = $1;
				my $formy = $2;
				print $out "    <sjp:odmiana>\n";
				print $out "      <rdf:Description>\n";
				print $out "        <sjp:flaga>$flaga</sjp:flaga>\n";
				print $out "        <sjp:formy>$formy</sjp:formy>\n";
				print $out "      </rdf:Description>\n";
				print $out "    </sjp:odmiana>\n";
				for my $form (split/, /, $formy) {
					print $out "    <gold:hasForm>$form</gold:hasForm>\n";
				}
			}
			if ($odm == 1 && m!<tr><th scope="row" valign="top">\(ręcznie dopisane\) <tt>~</tt></th><td>([^<]*)</td></tr>!) {
				print STDERR "1: $1\n";
				my $formy = $1;
				print $out "    <sjp:odmiana>\n";
				print $out "      <rdf:Description>\n";
				print $out "        <sjp:formy>$formy</sjp:formy>\n";
				print $out "      </rdf:Description>\n";
				print $out "    </sjp:odmiana>\n";
				for my $form (split/, /, $formy) {
					print $out "    <gold:hasForm>$form</gold:hasForm>\n";
				}
			}

		}
	}
}

# This seems a little too simple, will probably need to change it later.
sub split_defs {
	my $def = shift;
	my @defs = ();
	if (substr ($def, 0, 3) eq "1. ") {
	        my ($car, $cdr);
	        my $rest = substr($def, 3);
	        my $next = 2;
	        do {
	                ($car, $cdr) = split / $next\. /, $rest;
	                push @defs, $car;
	                $rest = $cdr;
	                $next++;
	        } while ($def =~ / $next\. /);
	        push @defs, $cdr;
	}
	return @defs;
}

doheader ($fh);

if ($#ARGV < 0) {
	my $file = "/dev/stdin";
	binmode $file, ":encoding(iso-8859-2)";
	procinner ($file, $fh);
} else {
	for my $filename (@ARGV) {
		my $file;
		open ($file, "<$filename");
		binmode $file, ":encoding(iso-8859-2)";
		procinner ($file, $fh);
		close $file;
	}
}
dofooter ($fh);

