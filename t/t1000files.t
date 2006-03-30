#!perl -w

# This file is for testing file functionality that is independent of
# the file format

use strict;
use lib 't';
use Test::More tests => 27;
use Imager;

Imager::init_log("testout/t1000files.log", 1);

SKIP:
{
  # Initally I tried to write this test using open to redirect files,
  # but there was a buffering problem that made it so the data wasn't
  # being written to the output file.  This external perl call avoids
  # that problem

  my $test_script = 'testout/t1000files_probe.pl';

  # build a temp test script to use
  ok(open(SCRIPT, "> $test_script"), "open test script")
    or skip("no test script $test_script: $!", 2);
  print SCRIPT <<'PERL';
#!perl
use Imager;
use strict;
my $file = shift or die "No file supplied";
open FH, "< $file" or die "Cannot open file: $!";
binmode FH;
my $io = Imager::io_new_fd(fileno(FH));
Imager::i_test_format_probe($io, -1);
PERL
  close SCRIPT;
  my $perl = $^X;
  $perl = qq/"$perl"/ if $perl =~ / /;
  
  print "# script: $test_script\n";
  my $cmd = "$perl -Mblib $test_script t/t1000files.t";
  print "# command: $cmd\n";

  my $out = `$cmd`;
  is($?, 0, "command successful");
  is($out, '', "output should be empty");
}

# test the file limit functions
# by default the limits are zero (unlimited)
print "# image file limits\n";
is_deeply([ Imager->get_file_limits() ], [0, 0, 0],
	  "check defaults");
ok(Imager->set_file_limits(width=>100), "set only width");
is_deeply([ Imager->get_file_limits() ], [100, 0, 0 ],
	  "check width set");
ok(Imager->set_file_limits(height=>150, bytes=>10000),
   "set height and bytes");
is_deeply([ Imager->get_file_limits() ], [ 100, 150, 10000 ],
	  "check all values now set");
ok(Imager->set_file_limits(reset=>1, height => 99),
   "set height and reset");
is_deeply([ Imager->get_file_limits() ], [ 0, 99, 0 ],
	  "check only height is set");
ok(Imager->set_file_limits(reset=>1),
   "just reset");
is_deeply([ Imager->get_file_limits() ], [ 0, 0, 0 ],
	  "check all are reset");

# check file type probe
probe_ok("49492A41", undef, "not quite tiff");
probe_ok("4D4D0041", undef, "not quite tiff");
probe_ok("49492A00", "tiff", "tiff intel");
probe_ok("4D4D002A", "tiff", "tiff motorola");
probe_ok("474946383961", "gif", "gif 89");
probe_ok("474946383761", "gif", "gif 87");
probe_ok(<<TGA, "tga", "TGA");
00 00 0A 00 00 00 00 00 00 00 00 00 96 00 96 00
18 20 FF 00 00 00 95 00 00 00 FF 00 00 00 95 00
00 00 FF 00 00 00 95 00 00 00 FF 00 00 00 95 00
00 00 FF 00 00 00 95 00 00 00 FF 00 00 00 95 00
TGA

probe_ok(<<ICO, "ico", "Windows Icon");
00 00 01 00 02 00 20 20 10 00 00 00 00 00 E8 02
00 00 26 00 00 00 20 20 00 00 00 00 00 00 A8 08
00 00 0E 03 00 00 28 00 00 00 20 00 00 00 40 00
ICO

probe_ok(<<RGB, "rgb", "SGI RGB");
01 DA 01 01 00 03 00 96 00 96 00 03 00 00 00 00 
00 00 00 FF 00 00 00 00 6E 6F 20 6E 61 6D 65 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
RGB

probe_ok(<<ILBM, "ilbm", "ILBM");
46 4F 52 4D 00 00 60 7A 49 4C 42 4D 42 4D 48 44
00 00 00 14 00 96 00 96 00 00 00 00 18 00 01 80
00 00 0A 0A 00 96 00 96 42 4F 44 59 00 00 60 51
ILBM

probe_ok(<<XPM, "xpm", "XPM");
2F 2A 20 58 50 4D 20 2A 2F 0A 73 74 61 74 69 63
20 63 68 61 72 20 2A 6E 6F 6E 61 6D 65 5B 5D 20
3D 20 7B 0A 2F 2A 20 77 69 64 74 68 20 68 65 69
XPM

probe_ok(<<PCX, "pcx", 'PCX');
0A 05 01 08 00 00 00 00 95 00 95 00 96 00 96 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
PCX

probe_ok(<<FITS, "fits", "FITS");
53 49 4D 50 4C 45 20 20 3D 20 20 20 20 20 20 20 
20 20 20 20 20 20 20 20 20 20 20 20 20 54 20 20 
20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 
FITS

probe_ok(<<PSD, "psd", "Photoshop");
38 42 50 53 00 01 00 00 00 00 00 00 00 06 00 00
00 3C 00 00 00 96 00 08 00 03 00 00 00 00 00 00
0B E6 38 42 49 4D 03 ED 00 00 00 00 00 10 00 90
PSD

probe_ok(<<EPS, "eps", "Encapsulated Postscript");
25 21 50 53 2D 41 64 6F 62 65 2D 32 2E 30 20 45
50 53 46 2D 32 2E 30 0A 25 25 43 72 65 61 74 6F
72 3A 20 70 6E 6D 74 6F 70 73 0A 25 25 54 69 74
EPS

sub probe_ok {
  my ($packed, $exp_type, $name) = @_;

  my $builder = Test::Builder->new;
  $packed =~ tr/ \r\n//d; # remove whitespace used for layout
  my $data = pack("H*", $packed);

  my $io = Imager::io_new_buffer($data);
  my $result = Imager::i_test_format_probe($io, -1);

  return $builder->is_eq($result, $exp_type, $name)
}
