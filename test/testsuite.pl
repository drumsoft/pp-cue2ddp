#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

my %cuesheets;
my %waves;
my @test_outputs;

my $targetpath = '../pp-cue2ddp.pl';
my $targetname = 'pp-cue2ddp';

my $format_samplerate = 44100;
my $format_channels = 2;
my $format_bits = 16;
my $format_encoding = 'signed-integer';
my $format_endian = 'little';

sub main {
	my $command = $ARGV[0] || '';

	if ( grep $command, qw(prepare clean test all) ) {
		main->$command();
	} else {
		print "usage: ./testsuite.pl prepare|clean|test \n";
	}
}

sub all {
	clean();
	prepare();
	test();
}

sub test {
	my $r;
	plan tests => 6;

	$r = system "$targetpath test-1-in.cue";
	ok(!$r, "execute with cue 1");
	$r = system "diff test-1-expected.cue test-1-in.out.cue";
	ok(!$r, "cue 1 cuesheet output");
	$r = system "diff test-1-expected.bin test-1-in.out.bin";
	ok(!$r, "cue 1 bin output");

	$r = system "$targetpath test-2-in.cue";
	ok(!$r, "execute with cue 2");
	$r = system "diff test-2-expected.cue test-2-in.out.cue";
	ok(!$r, "cue 2 cuesheet output");
	$r = system "diff test-2-expected.bin test-2-in.out.bin";
	ok(!$r, "cue 2 bin output");
}

sub clean {
	for my $filename ( keys %cuesheets ) {
		unlink "$filename";
	}
	for my $filename ( keys %waves ) {
		unlink "$filename.bin";
		unlink "$filename";
	}
	for my $filename ( @test_outputs ) {
		unlink "$filename";
	}
}

sub prepare {
	for my $filename ( keys %cuesheets ) {
		my $out;
		open $out, '>', $filename or die "fail: open $filename";
		print $out $cuesheets{$filename};
		close $out;
	}
	
	for my $filename ( keys %waves ) {
		my $out;
		open $out, '>', "$filename.bin" or die "fail: open $filename.bin";
		binmode $out;
		my @wave = @{ $waves{$filename} };
		while ( @wave ) {
			my $length = shift @wave;
			my $value  = shift @wave;
			print $out pack('v', $value) x ($length * $format_channels);
		}
		close $out;
		
		if ( $filename =~ /\.bin$/ ) {
			rename "$filename.bin", "$filename" or die "fail: rename $filename.bin";
		} else {
			my $sox = "sox --rate $format_samplerate --bits $format_bits --channels $format_channels --encoding $format_encoding --endian $format_endian --type raw $filename.bin $filename";
			system $sox and die "fail: sox $sox";
			unlink "$filename.bin" or die "fail: rm $filename";
		}
	}
}

# ------------------------------------------------------
$waves{'test-1-in.wav'} = [qw(
	238140	1 
	202860	2
)];
$waves{'test-2-in.aiff'} = [qw(
	88200	3
	88200	4
	176400	5
)];
$waves{'test-1-expected.bin'} = [qw(
	88200	0
	238140	1
	44100	0
	202860	2
	66150	0
	  294	0
	88200	4
	88464	5
	  324	0
	132300	0
)];
$waves{'test-2-expected.bin'} = [qw(
	88200	0
	238140	1
	202860	2
	66150	0
	44364	5
	176400	0
)];

# ------------------------------------------------------
$cuesheets{'test-1-in.cue'} =<<END_OF_CUESHEET;
REM test cue sheet for $targetname 1
PERFORMER_ALL "test performer all"
SONGWRITER_ALL "test songwriter all"
TITLE "test title"
FLAGS DCP
ALIGNFRAME
PREGAP 2
POSTGAP 1

FILE "test-1-in.wav"

TRACK 2 AUDIO
FLAGS PRE
TITLE "test title 2"
PERFORMER "test performer ow track2"
SONGWRITER "test songwriter ow track2"
PREGAP 0
INDEX 00 0:5:30
POSTGAP 0

TRACK 1 AUDIO
TITLE "test title 1"

FILE "test-2-in.aiff"
TRACK 3 AUDIO
PREGAP 1.5
INDEX 0 2.0
INDEX 1 4
INDEX 2 5
END 0:6.006
POSTGAP 3

END_OF_CUESHEET

# ------------------------------------------------------
$cuesheets{'test-2-in.cue'} =<<END_OF_CUESHEET;
REM test cue sheet for $targetname 2
PERFORMER "test performer album"
SONGWRITER "test songwriter album"
REM test comment

FILE "test-1-in.wav"
TRACK 1 AUDIO
PREGAP 2.0

FILE "test-2-in.aiff"
TRACK 2 AUDIO
FLAGS DCP
TITLE "test title 2"
PERFORMER "test performer track2"
SONGWRITER "test songwriter track2"
PREGAP 1.5
INDEX 01 0:5:0
END 0:6.006
POSTGAP 4.0

END_OF_CUESHEET

# ------------------------------------------------------
$cuesheets{'test-1-expected.cue'} =<<END_OF_CUESHEET;
REM test cue sheet for $targetname 1
TITLE "test title"
PERFORMER "test performer all"
SONGWRITER "test songwriter all"
FILE "test-1-in.out.bin" BINARY
TRACK 01 AUDIO
FLAGS DCP
TITLE "test title 1"
PERFORMER "test performer all"
SONGWRITER "test songwriter all"
INDEX 00 00:00:00
INDEX 01 00:02:00
TRACK 02 AUDIO
FLAGS DCP PRE
TITLE "test title 2"
PERFORMER "test performer ow track2"
SONGWRITER "test songwriter ow track2"
INDEX 01 00:08:30
TRACK 03 AUDIO
FLAGS DCP
PERFORMER "test performer all"
SONGWRITER "test songwriter all"
INDEX 00 00:13:00
INDEX 01 00:16:38
INDEX 02 00:17:38
END_OF_CUESHEET

# ------------------------------------------------------
$cuesheets{'test-2-expected.cue'} =<<END_OF_CUESHEET;
REM test cue sheet for $targetname 2
REM test comment
PERFORMER "test performer album"
SONGWRITER "test songwriter album"
FILE "test-2-in.out.bin" BINARY
TRACK 01 AUDIO
INDEX 00 00:00:00
INDEX 01 00:02:00
TRACK 02 AUDIO
FLAGS DCP
TITLE "test title 2"
PERFORMER "test performer track2"
SONGWRITER "test songwriter track2"
INDEX 00 00:12:00
INDEX 01 00:13:37
END_OF_CUESHEET

# ------------------------------------------------------
@test_outputs = qw(
	test-1-in.out.cue
	test-1-in.out.bin
	test-2-in.out.cue
	test-2-in.out.bin
);

# ------------------------------------------------------

main();

