#!perl -w

BEGIN { $| = 1; print "1..29\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
#use Data::Dumper;
$loaded = 1;
print "ok 1\n";
init_log("testout/t020masked.t", 1);

package Imager; # yes, I'm lazy

my $base_rgb = Imager::ImgRaw::new(100, 100, 3);
# put something in there
my $red = NC(255, 0, 0);
my $green = NC(0, 255, 0);
my $blue = NC(0, 0, 255);
my $white = NC(255, 255, 255);
my @cols = ($red, $green, $blue);
for my $y (0..99) {
  i_plin($base_rgb, 0, $y, ($cols[$y % 3] ) x 100);
}

# first a simple subset image
my $s_rgb = i_img_masked_new($base_rgb, undef, 25, 25, 50, 50);

print i_img_getchannels($s_rgb) == 3
  ? "ok 2\n" : "not ok 2 # 1 channel image channel count mismatch\n";
print i_img_getmask($s_rgb) & 1 
  ? "ok 3\n" : "not ok 3 # 1 channel image bad mask\n";
print i_img_virtual($s_rgb) == 0
  ? "not ok 4 # 1 channel image thinks it isn't virtual\n" : "ok 4\n";
print i_img_bits($s_rgb) == 8
  ? "ok 5\n" : "not ok 5 # 1 channel image has bits != 8\n";
print i_img_type($s_rgb) == 0 # direct
  ? "ok 6\n" : "not ok 6 # 1 channel image isn't direct\n";

my @ginfo = i_img_info($s_rgb);
print $ginfo[0] == 50 
  ? "ok 7\n" : "not ok 7 # image width incorrect\n";
print $ginfo[1] == 50
  ? "ok 8\n" : "not ok 8 # image height incorrect\n";

# sample some pixels through the subset
my $c = i_get_pixel($s_rgb, 0, 0);
color_cmp($c, $green) == 0 or print "not ";
print "ok 9\n";
$c = i_get_pixel($s_rgb, 49, 49);
# (25+49)%3 = 2
color_cmp($c, $blue) == 0 or print "not ";
print "ok 10\n";

# try writing to it
for my $y (0..49) {
  i_plin($s_rgb, 0, $y, ($cols[$y % 3]) x 50);
}
print "ok 11\n";
# and checking the target image
$c = i_get_pixel($base_rgb, 25, 25);
color_cmp($c, $red) == 0 or print "not ";
print "ok 12\n";
$c = i_get_pixel($base_rgb, 29, 29);
color_cmp($c, $green) == 0 or print "not ";
print "ok 13\n";

undef $s_rgb;

# a basic background
for my $y (0..99) {
  i_plin($base_rgb, 0, $y, ($red ) x 100);
}
my $mask = Imager::ImgRaw::new(50, 50, 1);
# some venetian blinds
for my $y (4..20) {
  i_plin($mask, 5, $y*2, ($white) x 40);
}
# with a strip down the middle
for my $y (0..49) {
  i_plin($mask, 20, $y, ($white) x 8);
}
my $m_rgb = i_img_masked_new($base_rgb, $mask, 25, 25, 50, 50);
$m_rgb or print "not ";
print "ok 14\n";
for my $y (0..49) {
  i_plin($m_rgb, 0, $y, ($green) x 50);
}
my @color_tests =
  (
   [ 25+0,  25+0,  $red ],
   [ 25+19, 25+0,  $red ],
   [ 25+20, 25+0,  $green ],
   [ 25+27, 25+0,  $green ],
   [ 25+28, 25+0,  $red ],
   [ 25+49, 25+0,  $red ],
   [ 25+19, 25+7,  $red ],
   [ 25+19, 25+8,  $green ],
   [ 25+19, 25+9,  $red ],
   [ 25+0,  25+8,  $red ],
   [ 25+4,  25+8,  $red ],
   [ 25+5,  25+8,  $green ],
   [ 25+44, 25+8,  $green ],
   [ 25+45, 25+8,  $red ],
   [ 25+49, 25+49, $red ],
  );
my $test_num = 15;
for my $test (@color_tests) {
  color_test($test_num++, $base_rgb, @$test);
}

sub color_test {
  my ($num, $im, $x, $y, $expected) = @_;
  my $c = i_get_pixel($im, $x, $y);
  color_cmp($c, $expected) == 0 or print "not ";
  print "ok $num # $x, $y\n";
}

sub color_cmp {
  my ($l, $r) = @_;
  my @l = $l->rgba;
  my @r = $r->rgba;
  return $l[0] <=> $r[0]
    || $l[1] <=> $r[1]
      || $l[2] <=> $r[2];
}

