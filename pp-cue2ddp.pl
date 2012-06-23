#!/usr/bin/perl

# pp-cue2ddp.pl by Haruka Kataoka 2012
# pp-cue2ddp.pl is an 'preprocessor' for cue2ddp from 'DDP Mastering Tools for the Command Line'.
# cue2ddp and 'DDP Mastering Tools for the Command Line' is created by Andreas Ruge. the tool is here http://ddp.andreasruge.de/ .

use strict;
use warnings;
use utf8;

use File::Spec;
use Getopt::Long;

# ----------------------------------------------------
my $format_samplerate = 44100;
my $format_channels = 2;
my $format_bits = 16;
my $format_encoding = 'signed-integer';
my $format_endian = 'little';
my $frames_second = 75;
my $samples_frame = $format_samplerate / $frames_second;
my $bytes_sample = $format_channels * ($format_bits / 8);

my $re_spc = '[\s\t\n\r]+';

# ----------------------------------------------------
my $exec_cue2ddp = 0;
GetOptions('exec-cue2ddp' => \$exec_cue2ddp);
if ( ! defined $ARGV[0] ) {
	print "usage: " . __FILE__ . " [--exec_cue2ddp] cuefile\n";
	exit 0;
}
main($ARGV[0]);

# ----------------------------------------------------
sub main {
	my $cuefile = shift;
	die "cannot open $cuefile" if ! -r $cuefile;

	# prepare pathes
	if ( ! File::Spec->file_name_is_absolute( $cuefile ) ) {
		$cuefile = File::Spec->rel2abs( $cuefile );
	}
	my ($volume,$directories,$file) = File::Spec->splitpath( $cuefile );
	my $basepath = File::Spec->catpath( $volume, $directories );
	my $output = $cuefile;
	$output =~ s/\.\w+$/\.out/;

	# parse
	my $cue = parse_cuefile(read_cuefile($cuefile));

	# convert files
	my %wav_files;
	foreach ( @{ $cue->{TRACKS} } ) {
		$wav_files{ $_->{FILE} } = 1;
	}
	foreach ( keys %wav_files ) {
		my $path = File::Spec->rel2abs($_, $basepath);
		$wav_files{$_} = prepare_file($path);
	}

	# concat wave files
	concat_waves("$output.bin", $cue, \%wav_files);
	print "sound file created: $output.bin\n";

	# clean temp files
	foreach (values %wav_files) {
		unlink $_->{path};
	}

	# write cur file
	write_cue("$output.cue", "$output.bin", $cue);
	print "cue file created: $output.cue\n";

	# exec
	if ($exec_cue2ddp) {
		mkdir "$output" if ! -d "$output";
		system(qq{cue2ddp -ct -m "$output" "$output.cue" "$output"}) and die "cue2ddp error";
	}
}

sub union {
	my %union;
	@union{ @_ } = 1;
	return keys %union;
}

sub write_cue {
	my $output = shift;
	my $audiofile = shift;
	my $cue = shift;

	open my $out, '>', $output;
	select $out;

	my $common_print = sub {
		my $current = shift;
		print join '', map {"$_\n"} @{$current->{OTHERS}};
		foreach my $key (qw(PERFORMER SONGWRITER)) {
			my $value = defined $current->{$key} ? $current->{$key} : defined $cue->{$key.'_ALL'} ? $cue->{$key.'_ALL'} : undef;
			printf qq{$key $value\n} if defined $value;
		}
	};

	$common_print->($cue);
	my ($v,$d,$filename) = File::Spec->splitpath( $audiofile );
	print qq{FILE "$filename" BINARY\n};

	foreach my $track ( @{$cue->{TRACKS}} ) {
		printf "TRACK %02d AUDIO\n", $track->{NUMBER};
		if ( defined $track->{FLAGS} || defined $cue->{FLAGS} ) {
			printf qq{FLAGS %s\n}, 
			       join ' ', sort {$a cmp $b} 
			       union( defined $track->{FLAGS} ? @{$track->{FLAGS}} : (), 
			              defined   $cue->{FLAGS} ? @{  $cue->{FLAGS}} : () );
		}
		$common_print->($track);
		if ( $track->{INDEXES}->[0] != $track->{INDEXES}->[1] ) {
			printf "INDEX 00 %s\n", encode_time($track->{INDEXES}->[0]);
		}
		for( my $i = 1; $i < @{$track->{INDEXES}}; $i++ ) {
			next if ! defined $track->{INDEXES}->[$i];
			printf "INDEX %02d %s\n", $i, encode_time($track->{INDEXES}->[$i]);
		}
	}

	close $out;
	select STDOUT;
}

sub align_frame {
	my $samples = int(shift);
	my $modulo = $samples % $samples_frame;
	return $modulo == 0 ? $samples : $samples - $modulo + $samples_frame;
}

sub concat_waves {
	my $output = shift;
	my $cue = shift;
	my $wav_files = shift;

	my $wav;
	open $wav, '>', $output;
	binmode $wav;
	my $position = 0; # position of track start (start of pregap)

	foreach ( @{ $cue->{TRACKS} } ) {
		my $pregap  = defined $_->{PREGAP}  ? $_->{PREGAP}  : defined $cue->{PREGAP}  ? $cue->{PREGAP}  : 0;
		my $postgap = defined $_->{POSTGAP} ? $_->{POSTGAP} : defined $cue->{POSTGAP} ? $cue->{POSTGAP} : 0;
		my $padding = 0;
		my $readstart = 0;
		my $readlength = 0;

		# add pregap
		if ( $pregap > 0 ) {
			$pregap = $cue->{ALIGNFRAME} ? align_frame($pregap) : int($pregap);
			print $wav pack('C', 0) x ($pregap * $bytes_sample);
		}

		# add wave
		my $file = $wav_files->{ $_->{FILE} };
		my ($in, $buffer);
		$readstart = $_->{INDEXES}->[0];
		$readlength = (defined $_->{END} ? $_->{END} : $file->{length}) - $readstart;
		open $in, $file->{path} or die "cannot read $file";
		binmode $in;
		seek $in, $readstart * $bytes_sample, 0;
		read $in, $buffer, $readlength * $bytes_sample;
		print $wav $buffer;
		close $in;

		foreach my $idx ( @{ $_->{INDEXES} } ) {
			$idx += -$readstart + $position + $pregap;
		}
		$_->{INDEXES}->[0] -= $pregap;

		# padding wave
		if ( $cue->{ALIGNFRAME} ) {
			my $modulo = $readlength % $samples_frame;
			if ($modulo > 0) {
				$padding = $samples_frame - $modulo;
				print $wav pack('C', 0) x ($padding * $bytes_sample);
			}
		}

		# add postgap
		if ( $postgap > 0 ) {
			$postgap = $cue->{ALIGNFRAME} ? align_frame($postgap) : int($postgap);
			print $wav pack('C', 0) x ($postgap * $bytes_sample);
		}
		$position += $pregap + $readlength + $padding + $postgap;
	}

	close $wav;
}

sub prepare_file {
	my $path = shift;
	die "$path is not exists." if ! -e $path;
	die "$path is not readable." if ! -r $path;

	my ($v, $d, $filename) = File::Spec->splitpath($path);
	my $newpath = File::Spec->catfile(File::Spec->tmpdir(), "$filename.converted.bin");
	my $soxcmd = qq{sox "$path" --rate $format_samplerate --bits $format_bits --channels $format_channels --encoding $format_encoding --endian $format_endian --type raw "$newpath"};
	system($soxcmd) and die "sox failed: $soxcmd";

	return {
		path => $newpath,
		length => (stat($newpath))[7] / $bytes_sample
	};
}


sub read_cuefile {
	my $file = shift;
	my @cuefile;
	open my($in), $file;
	@cuefile = <$in>;
	close $in;
	return @cuefile;
}

# encode internal time (sample frames) to time description for cue sheet (mm:ss:ff)
sub encode_time {
	my $t = shift;
	my $seconds = int( $t / $format_samplerate );
	my $frames  = int( ($t - $seconds * $format_samplerate) / $samples_frame );
	my $minutes = int( $seconds / 60 );
	   $seconds =      $seconds % 60;
	return sprintf "%02d:%02d:%02d", $minutes, $seconds, $frames;
}

# decode time description (mm:ss:ff or mm:ss.sss or ss.sss) to internal time (sample frames)
sub decode_time {
	my $t = shift;
	if ($t =~ /^(\d+):(\d+):(\d+)$/) {
		return ($1 * 60 * $format_samplerate) +    ($2 * $format_samplerate) + ($3 * $samples_frame);
	} elsif ($t =~ /^(\d+):(\d+(?:\.\d+)?)$/) {
		return ($1 * 60 * $format_samplerate) + int($2 * $format_samplerate);
	} elsif ($t =~ /^\d+(?:\.\d+)?$/) {
		return                                  int($t * $format_samplerate);
	} else {
		die "cannot parse time '$t'.";
	}
}

# parse and get first string token. get next token calling with no argment.
BEGIN {
my $line;
sub parse_string {
	my $t_line = shift;
	my @return = ();
	if (defined $t_line) {
		$line = $t_line;
	}
	while ( 1 ) {
		$line =~ s/^$re_spc//g;
		if ( $line =~ /^"/ ) { #"
			if ( $line =~ s/^(".*")// ) {
				push @return, $1;
			} else {
				die "double quote unmatch near $line";
			}
		} else {
			if ( $line =~ s/^([^\r\s\n\r]+)// ) {
				push @return, $1;
			} else {
				last;
			}
		}
		last if ! wantarray;
	}
	return wantarray ? @return : $return[0];
}
}

sub strip_quote {
	my $s = shift;
	$s =~ s/^"(.*)"$/$1/;
	return $s;
}

sub parse_cuefile {
	my @cuefile = @_;
	my %cue = (
		OTHERS => [],
		TRACKS => [],
	);
	my $file;
	my $command;
	my (%process_global, %process_track);
	my $process = \%process_global;
	my $cur = \%cue;
	my $newtrack = sub {
		{
			OTHERS => [],
			NUMBER => shift,
			FILE => $file,
		}
	};

	%process_global = (
		PERFORMER_ALL  => sub{ $cur->{$_[0]} = parse_string(); },
		SONGWRITER_ALL => sub{ $cur->{$_[0]} = parse_string(); },
		PERFORMER  => sub{ $cur->{$_[0]} = parse_string(); },
		SONGWRITER => sub{ $cur->{$_[0]} = parse_string(); },
		FLAGS      => sub{ $cur->{$_[0]} = [parse_string()]; },
		FILE       => sub{ $file = strip_quote(scalar parse_string()); },
		ALIGNFRAME => sub{ $cur->{$_[0]} = 1; },
		PREGAP     => sub{ $cur->{$_[0]} = decode_time(scalar parse_string()); },
		POSTGAP    => sub{ $cur->{$_[0]} = decode_time(scalar parse_string()); },
		TRACK      => sub{ 
			$process = \%process_track; 
			$cur = $newtrack->(1 * parse_string()); 
			push @{$cue{TRACKS}}, $cur;
		},
	);
	%process_track = (
		PERFORMER  => $process_global{PERFORMER},
		SONGWRITER => $process_global{SONGWRITER},
		FLAGS      => $process_global{FLAGS},
		FILE       => $process_global{FILE},
		INDEX      => sub{ 
			my ($idx, $value) = parse_string();
			$cur->{INDEXES}->[1*$idx] = decode_time($value);
		},
		PREGAP     => $process_global{PREGAP},
		POSTGAP    => $process_global{POSTGAP},
		END        => sub{ $cur->{$_[0]} = decode_time(scalar parse_string()); },
		TRACK      => sub{ 
			$cur = $newtrack->(1 * parse_string()); 
			push @{$cue{TRACKS}}, $cur;
		},
	);

	# parse line by line
	my $count = 1;
	foreach ( @cuefile ) {
		$count++;
		my $line = $_;
		$line =~ s/^$re_spc|$re_spc$//g;
		next if $line eq '';
		$command = uc parse_string( $line );
		if ( $command !~ /^([A-Z_]+)$/ ) {
			warn "syntax error near '$command' on line $count of cuefile.";
		}
		if ( exists $process->{$command} ) {
			$process->{$command}->($command);
		} else {
			push @{ $cur->{OTHERS} }, $line;
		}
	}

	# sort
	$cue{TRACKS} = [sort { $a->{NUMBER} <=> $b->{NUMBER} } @{ $cue{TRACKS} }];

	my $prev;
	foreach ( @{ $cue{TRACKS} } ) {
		if      ( !defined $_->{INDEXES}->[0] && !defined $_->{INDEXES}->[1]) {
			$_->{INDEXES}->[0] = $_->{INDEXES}->[1] = 0;
		} elsif ( !defined $_->{INDEXES}->[0] &&  defined $_->{INDEXES}->[1] ) {
			$_->{INDEXES}->[0] = $_->{INDEXES}->[1];
		} elsif (  defined $_->{INDEXES}->[0] && !defined $_->{INDEXES}->[1] ) {
			$_->{INDEXES}->[1] = $_->{INDEXES}->[0];
		} elsif ( $_->{INDEXES}->[0] > $_->{INDEXES}->[1] ) {
			$_->{INDEXES}->[0] = $_->{INDEXES}->[1];
		}
		if ( defined $prev ) {
			if ( ! defined $prev->{END} && ($_->{FILE} eq $prev->{FILE}) ) {
				$prev->{END} = $_->{INDEXES}->[0];
			}
		}
		$prev = $_;
	}

	return \%cue;
}


__END__

# structure of $cue

master
	OTHERS	through outputs
	TRACKS	tracks ref of list
	PERFORMER_ALL	this value is copied to global and all tracks as PERFORMER value
	SONGWRITER_ALL	this value is copied to global and all tracks as SONGWRITER value
	PERFORMER, SONGWRITER	cd-text value
	FLAGS	ref of list of FLAGS values.
	ALIGNFRAME	defined when 'align to flame' is set.
tracks
	PERFORMER, SONGWRITER	cd-text value
	OTHERS	through outputs
	NUMBER	track number
	FILE	wave file
	INDEXES	indexes ref of list
	END	end of track
	PREGAP	pregap samples
	POSTGAP	postgap samples

# memos for me

http://ddp.andreasruge.de/
http://ddp.andreasruge.de/cue2ddp.html
http://www.telomeregroup.com/CUE.SHEET.html
http://digitalx.org/cue-sheet/syntax/
