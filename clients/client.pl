#!/usr/bin/perl
require 5.004;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use JSON;
use Encode qw(decode);

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";


sub xlate {
	(my $text, my $fns) = @_;
	my $ua = LWP::UserAgent->new();
	$ua->timeout(15);
    my $r = POST('http://borel.slu.edu/cgi-bin/seirbhis3.cgi',
				[ 'teacs' => $text, 'foinse' => $fns ]);
    my $response = $ua->request($r);
	if ($response->is_success) { 
	    my $arrayref;
		if (!defined(eval { $arrayref = from_json(decode('utf8',$response->content)) }) or
			!defined($arrayref) or ref($arrayref) ne 'ARRAY') {
			print STDERR "Didn't understand the response from the server\n";
		}
		else {
			#print decode('utf8',$response->content)."\n\n";
			my $t = '';
			for my $p (@{$arrayref}) {
				$t .= $p->[0].' => '.$p->[1]."\n";
			}
			return $t;
		}
	}
	else {
		# timeout, or connection refused usually
		print STDERR "Unable to connect with the server. Please try again later.\n";
	}
	return undef;
}

die "Usage: perl client.pl [gd|gv]" if (scalar @ARGV != 1);
my $foinse = $ARGV[0];
die "Usage: perl client.pl [gd|gv]" unless ($foinse eq 'gd' or $foinse eq 'gv');

my $slurp;
while (<STDIN>) {
	$slurp .= $_;
}

print xlate($slurp, $foinse); 

exit 0;