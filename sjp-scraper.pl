#!/usr/bin/perl

use warnings;
use strict;
use utf8;

use Data::Dumper;
use URI::Escape;
use HTML::Entities;

open (my $fh, ">/tmp/writer.rdf");
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
	print $out "    xmlns:sjp=\"http://example.com/sjp/\"\n";
	print $out "    xml:lang=\"pl\">\n";
}

sub dofooter {
	my $out = shift;

	print $out "</rdf:RDF>\n";
}

sub procinner {
	my $out = shift;

	my $odm = 0;
	my ($haslo, $eschaslo, $num);

	while(<>) {
		chomp;
		if (m!<h1 style="font-family: Verdana, sans-serif;">([^<]*)</h1>!) {
			print STDERR "-> $_ : word: $1\n" if ($debug);
			$word = $1;
			$escword = uri_escape_utf8($word);
			print $out "  <sjp:haslo rdf:about=\"http://www.sjp.pl/$escword\" rdfs:label=\"$escword\"/>\n";
		}

		if (defined $word) {
			if (m!<div class="wf">!) {
				$reading = 1;
			}
			if($reading == 1 && m!</table>!) {
				$reading = 0;
				$odm = 0;
   				print $out "  </sjp:forma>\n";
			}

			if (m!<b>([0-9]*)\. ($word)</b>!i) {
				print STDERR "-> $_ : $2 : $1\n" if ($debug);
				$haslo = "$2";
				$num = $1;
				$eschaslo = uri_escape_utf8($haslo);
   				print $out "  <sjp:forma rdf:about=\"http://www.sjp.pl/$eschaslo#$num\">\n";
				print $out "    <rdfs:seeAlso rdf:resource=\"http://www.sjp.pl/$escword\"/>\n";
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
		}
	}
}

doheader ($fh);
procinner ($fh);
dofooter ($fh);

