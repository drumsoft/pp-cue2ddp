pp-cue2ddp.pl

# WARNINGS

 * pp-cue2ddp.pl is not verified for real CD productions.


# outline

pp-cue2ddp.pl is an 'preprocessor' for cue2ddp from 'DDP Mastering Tools for the Command Line'.

With cue2ddp and pp-cue2ddp.pl, you can 'pre-mastering' from some audio files to a DDP fileset.

cue2ddp and 'DDP Mastering Tools for the Command Line' is created by Andreas Ruge. the tool is here http://ddp.andreasruge.de/ .


# features

 * Convert and concatenate audio files into one raw data.
 * Translate cue sheet commands which cue2ddp not supported. (ex. PREGAP to INDEX 00 gap)
 * Some expanded cue sheet syntax helps you. (ex. You can use floating point seconds instead of 1/75 second frames)


# make, test, install

    make               # just chmod script
    make test          # run test
    sudo make install  # install script to /usr/local/bin


# usage

    $ pp-cue2ddp.pl mycd.cue
    sound file created: mycd.out.bin
    cue file created: mycd.out.cue
    $ cue2ddp -ct -m "mycd-master-id" mycd.out.cue "mycd-ddpdirectory"

Or, auto cue2ddp execution:

    $ pp-cue2ddp.pl --exec-cue2ddp mycd.cue

with --exec-cue2ddp (or -e) option, pp-cue2ddp runs cue2ddp with -ct option and generates 'master-id' and 'ddpdirectory' from cuesheet filename.


# expanded cue sheet syntax

## global section
 * FLAGS:	when set, FLAGS are inserted after all 'TRACK's (will be summed with each track's FLAGS).
 * ALIGNFRAME:	when set, each PREGAP, POSTGAP and wave data will be zero-padded to align to frames before concat. otherwise, track indexes will be moved to previous frame align.
 * PERFORMER_ALL, SONGWRITER_ALL:	this value is copied to global and all tracks as PERFORMER and SONGWRITER value. overwritten by track's PERFORMER and SONGWRITER.
 * PREGAP, POSTGAP:	pregap and postgap for all tracks  (will be overwritten by track's PREGAP and POSTGAP).

## both global and track
 * FILE:	any filetypes which sox can convert are ok.

## track section
 * TRACK:	'AUDIO' only allowed.
 * END:	track end position in FILE.
 * INDEX:	if INDEX 01 are omitted, it's set to start of FILE.
 * PREGAP, POSTGAP:	supported. (they will be translated because cue2ddp not supports them)

The order of track sections will be collected by numbers.

Commands not described above are through printed to output cuesheet.


## time formats
times in INDEX, PREGAP, POSTGAP and END could be 3 formats.
 * MM:SS:FF   (minutes, seconds, frames(1/75 seconds))
 * MM:Seconds (minutes, seconds may be int or float)
 * Seconds    (seconds may be int or float)

## miscellaneous
 * Commands after TRACK will be reordered correctly. So, you can write PREGAP after INDEX.
 * PREGAP is inserted before INDEX 00. So, 2 pregaps set by 'PREGAP' and 'from INDEX 00 to 01' are summed.

