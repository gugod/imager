#!perl -w
# t/t01introvert.t - tests internals of image formats
# to make sure we get expected values
#
# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..52\n"; }
END {print "not ok 1\n" unless $loaded;}
use Imager;
#use Data::Dumper;
$loaded = 1;
print "ok 1\n";

init_log("testout/t01introvert.log",1);

package Imager; # so I'm lazy

my $im_g = Imager::ImgRaw::new(100, 101, 1);

print i_img_getchannels($im_g) == 1 
  ? "ok 2\n" : "not ok 2 # 1 channel image channel count mismatch\n";
print i_img_getmask($im_g) & 1 
  ? "ok 3\n" : "not ok 3 # 1 channel image bad mask\n";
print i_img_virtual($im_g) 
  ? "not ok 4 # 1 channel image thinks it is virtual\n" : "ok 4\n";
print i_img_bits($im_g) == 8
  ? "ok 5\n" : "not ok 5 # 1 channel image has bits != 8\n";
print i_img_type($im_g) == 0 # direct
  ? "ok 6\n" : "not ok 6 # 1 channel image isn't direct\n";

my @ginfo = i_img_info($im_g);
print $ginfo[0] == 100 
  ? "ok 7\n" : "not ok 7 # 1 channel image width incorrect\n";
print $ginfo[1] == 101
  ? "ok 8\n" : "not ok 8 # 1 channel image height incorrect\n";

undef $im_g; # can we check for release after this somehow?

my $im_rgb = Imager::ImgRaw::new(100, 101, 3);

print i_img_getchannels($im_rgb) == 3
  ? "ok 9\n" : "not ok 9 # 3 channel image channel count mismatch\n";
print +(i_img_getmask($im_rgb) & 7) == 7
  ? "ok 10\n" : "not ok 10 # 3 channel image bad mask\n";
print i_img_bits($im_rgb) == 8
  ? "ok 11\n" : "not ok 11 # 3 channel image has bits != 8\n";
print i_img_type($im_rgb) == 0 # direct
  ? "ok 12\n" : "not ok 12 # 3 channel image isn't direct\n";

undef $im_rgb;

my $im_pal = i_img_pal_new(100, 101, 3, 256);

print $im_pal ? "ok 13\n" : "not ok 13 # couldn't make paletted image\n";
print i_img_getchannels($im_pal) == 3
  ? "ok 14\n" : "not ok 14 # pal img channel count mismatch\n";
print i_img_bits($im_pal) == 8
  ? "ok 15\n" : "not ok 15 # pal img bits != 8\n";
print i_img_type($im_pal) == 1
  ? "ok 16\n" : "not ok 16 # pal img isn't paletted\n";

my $red = NC(255, 0, 0);
my $green = NC(0, 255, 0);
my $blue = NC(0, 0, 255);

my $red_idx = check_add(17, $im_pal, $red, 0);
my $green_idx = check_add(21, $im_pal, $green, 1);
my $blue_idx = check_add(25, $im_pal, $blue, 2);

# basic writing of palette indicies
# fill with red
i_ppal($im_pal, 0, 0, ($red_idx) x 100) == 100
  or print "not ";
print "ok 29\n";
# and blue
i_ppal($im_pal, 50, 0, ($blue_idx) x 50) == 50
  or print "not ";
print "ok 30\n";

# make sure we get it back
my @pals = i_gpal($im_pal, 0, 100, 0);
grep($_ != $red_idx, @pals[0..49]) and print "not ";
print "ok 31\n";
grep($_ != $blue_idx, @pals[50..99]) and print "not ";
print "ok 32\n";
i_gpal($im_pal, 0, 100, 0) eq "\0" x 50 . "\2" x 50 or print "not ";
print "ok 33\n";
my @samp = i_gsamp($im_pal, 0, 100, 0, 0, 1, 2);
@samp == 300 or print "not ";
print "ok 34\n";
my @samp_exp = ((255, 0, 0) x 50, (0, 0, 255) x 50);
my $diff = array_ncmp(\@samp, \@samp_exp);
$diff == 0 or print "not ";
print "ok 35\n";
my $samp = i_gsamp($im_pal, 0, 100, 0, 0, 1, 2);
length($samp) == 300 or print "not ";
print "ok 36\n";
$samp eq "\xFF\0\0" x 50 . "\0\0\xFF" x 50
  or print "not ";
print "ok 37\n";

# reading indicies as colors
my $c_red = i_get_pixel($im_pal, 0, 0)
  or print "not ";
print "ok 38\n";
color_cmp($red, $c_red) == 0
  or print "not ";
print "ok 39\n";
my $c_blue = i_get_pixel($im_pal, 50, 0)
  or print "not ";
print "ok 40\n";
color_cmp($blue, $c_blue) == 0
  or print "not ";
print "ok 41\n";

# drawing with colors
i_ppix($im_pal, 0, 0, $green) and print "not ";
print "ok 42\n";
# that was in the palette, should still be paletted
print i_img_type($im_pal) == 1
  ? "ok 43\n" : "not ok 43 # pal img isn't paletted (but still should be)\n";

my $c_green = i_get_pixel($im_pal, 0, 0)
  or print "not ";
print "ok 44\n";
color_cmp($green, $c_green) == 0
  or print "not ";
print "ok 45\n";

i_colorcount($im_pal) == 3 or print "not ";
print "ok 46\n";
i_findcolor($im_pal, $green) == 1 or print "not ";
print "ok 47\n";

my $black = NC(0, 0, 0);
# this should convert the image to RGB
i_ppix($im_pal, 1, 0, $black) and print "not ";
print "ok 48\n";
print i_img_type($im_pal) == 0
  ? "ok 49\n" : "not ok 49 # pal img shouldn't be paletted now\n";

my %quant =
  (
   colors => [$red, $green, $blue, $black],
   makemap => 'none',
  );
my $im_pal2 = i_img_to_pal($im_pal, \%quant);
$im_pal2 or print "not ";
print "ok 50\n";
@{$quant{colors}} == 4 or print "not ";
print "ok 51\n";
i_gsamp($im_pal2, 0, 100, 0, 0, 1, 2) eq "\0\xFF\0\0\0\0"."\xFF\0\0" x 48 . "\0\0\xFF" x 50
  or print "not ";
print "ok 52\n";

sub check_add {
  my ($base, $im, $color, $expected) = @_;
  my $index = i_addcolor($im, $color)
    or print "not ";
  print "ok ",$base++,"\n";
  $index == $expected
    or print "not ";
  print "ok ",$base++,"\n";
  my $new = i_getcolor($im, $index)
    or print "not ";
  print "ok ",$base++,"\n";
  color_cmp($new, $color) == 0
    or print "not ";
  print "ok ",$base++,"\n";

  $index;
}

sub color_cmp {
  my ($l, $r) = @_;
  my @l = $l->rgba;
  my @r = $r->rgba;
  return $l[0] <=> $r[0]
    || $l[1] <=> $r[1]
      || $l[2] <=> $r[2];
}

sub array_ncmp {
  my ($a1, $a2) = @_;
  my $len = @$a1 < @$a2 ? @$a1 : @$a2;
  for my $i (0..$len-1) {
    my $diff = $a1->[$i] <=> $a2->[$i] 
      and return $diff;
  }
  return @$a1 <=> @$a2;
}
