#!perl -w
use strict;
use lib 't';
use Test::More tests=>51;
use Imager;

#$Imager::DEBUG=1;

Imager::init('log'=>'testout/t64copyflip.log');

my $img=Imager->new() or die "unable to create image object\n";

$img->open(file=>'testimg/scale.ppm',type=>'pnm');
my $nimg = $img->copy();
ok($nimg, "copy returned something");

# test if ->copy() works

my $diff = Imager::i_img_diff($img->{IMG}, $nimg->{IMG});
is($diff, 0, "copy matches source");


# test if ->flip(dir=>'h')->flip(dir=>'h') doesn't alter the image

$nimg->flip(dir=>"h")->flip(dir=>"h");
$diff = Imager::i_img_diff($img->{IMG}, $nimg->{IMG});
is($diff, 0, "double horiz flipped matches original");

# test if ->flip(dir=>'v')->flip(dir=>'v') doesn't alter the image

$nimg->flip(dir=>"v")->flip(dir=>"v");
$diff = Imager::i_img_diff($img->{IMG}, $nimg->{IMG});
is($diff, 0, "double vertically flipped image matches original");


# test if ->flip(dir=>'h')->flip(dir=>'v') is same as ->flip(dir=>'hv')

$nimg->flip(dir=>"v")->flip(dir=>"h")->flip(dir=>"hv");;
$diff = Imager::i_img_diff($img->{IMG}, $nimg->{IMG});
is($diff, 0, "check flip with hv matches flip v then flip h");

rot_test($img, 90, 4);
rot_test($img, 180, 2);
rot_test($img, 270, 4);
rot_test($img, 0, 1);

my $pimg = $img->to_paletted();
rot_test($pimg, 90, 4);
rot_test($pimg, 180, 2);
rot_test($pimg, 270, 4);
rot_test($pimg, 0, 1);

my $timg = $img->rotate(right=>90)->rotate(right=>270);
is(Imager::i_img_diff($img->{IMG}, $timg->{IMG}), 0,
   "check rotate 90 then 270 matches original");
$timg = $img->rotate(right=>90)->rotate(right=>180)->rotate(right=>90);
is(Imager::i_img_diff($img->{IMG}, $timg->{IMG}), 0,
     "check rotate 90 then 180 then 90 matches original");

# this could use more tests
my $rimg = $img->rotate(degrees=>10);
ok($rimg, "rotation by 10 degrees gave us an image");
if (!$rimg->write(file=>"testout/t64_rot10.ppm")) {
  print "# Cannot save: ",$rimg->errstr,"\n";
}

# rotate with background
$rimg = $img->rotate(degrees=>10, back=>Imager::Color->new(builtin=>'red'));
ok($rimg, "rotate with background gave us an image");
if (!$rimg->write(file=>"testout/t64_rot10_back.ppm")) {
  print "# Cannot save: ",$rimg->errstr,"\n";
}
	

my $trimg = $img->matrix_transform(matrix=>[ 1.2, 0, 0,
                                             0,   1, 0,
                                             0,   0, 1]);
ok($trimg, "matrix_transform() returned an image");
$trimg->write(file=>"testout/t64_trans.ppm")
  or print "# Cannot save: ",$trimg->errstr,"\n";

$trimg = $img->matrix_transform(matrix=>[ 1.2, 0, 0,
                                             0,   1, 0,
                                             0,   0, 1],
				   back=>Imager::Color->new(builtin=>'blue'));
ok($trimg, "matrix_transform() with back returned an image");

$trimg->write(file=>"testout/t64_trans_back.ppm")
  or print "# Cannot save: ",$trimg->errstr,"\n";

sub rot_test {
  my ($src, $degrees, $count) = @_;

  my $cimg = $src->copy();
  my $in;
  for (1..$count) {
    $in = $cimg;
    $cimg = $cimg->rotate(right=>$degrees)
      or last;
  }
 SKIP:
  {
    ok($cimg, "got a rotated image")
      or skip("no image to check", 4);
    my $diff = Imager::i_img_diff($src->{IMG}, $cimg->{IMG});
    is($diff, 0, "check it matches source")
      or skip("didn't match", 3);

    # check that other parameters match
    is($src->type, $cimg->type, "type check");
    is($src->bits, $cimg->bits, "bits check");
    is($src->getchannels, $cimg->getchannels, "channels check");
  }
}

