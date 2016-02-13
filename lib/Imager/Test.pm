package Imager::Test;
use strict;
use Test::More;
use Test::Builder;
require Exporter;
use vars qw(@ISA @EXPORT_OK $VERSION);
use Carp qw(croak carp);
use Config;

$VERSION = "1.004";

@ISA = qw(Exporter);
@EXPORT_OK = 
  qw(
     diff_text_with_nul 
     test_image_raw
     test_image_16
     test_image
     test_image_double 
     test_image_mono
     test_image_gray
     test_image_gray_16
     test_image_named
     is_color1
     is_color3
     is_color4
     is_color_close3
     is_fcolor1
     is_fcolor3
     is_fcolor4
     is_arrayf
     color_cmp
     is_image
     is_imaged
     is_image_similar
     isnt_image
     image_bounds_checks
     mask_tests
     test_colorf_gpix
     test_color_gpix
     test_colorf_glin
     can_test_threads
     std_font_tests
     std_font_test_count
     std_image_tests
     std_image_tests_count
     to_linear_srgb
     to_linear_srgbf
     );

sub diff_text_with_nul {
  my ($desc, $text1, $text2, @params) = @_;

  my $builder = Test::Builder->new;

  print "# $desc\n";
  my $imbase = Imager->new(xsize => 100, ysize => 100);
  my $imcopy = Imager->new(xsize => 100, ysize => 100);

  $builder->ok($imbase->string(x => 5, 'y' => 50, size => 20,
			       string => $text1,
			       @params), "$desc - draw text1");
  $builder->ok($imcopy->string(x => 5, 'y' => 50, size => 20,
			       string => $text2,
			       @params), "$desc - draw text2");
  $builder->isnt_num(Imager::i_img_diff($imbase->{IMG}, $imcopy->{IMG}), 0,
		     "$desc - check result different");
}

sub is_color3($$$$$) {
  my ($color, $red, $green, $blue, $comment) = @_;

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cr, $cg, $cb) = $color->rgba;
  unless ($builder->ok($cr == $red && $cg == $green && $cb == $blue, $comment)) {
    print <<END_DIAG;
Color mismatch:
  Red: $red vs $cr
Green: $green vs $cg
 Blue: $blue vs $cb
END_DIAG
    return;
  }

  return 1;
}

sub is_color_close3($$$$$$) {
  my ($color, $red, $green, $blue, $tolerance, $comment) = @_;

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cr, $cg, $cb) = $color->rgba;
  unless ($builder->ok(abs($cr - $red) <= $tolerance
		       && abs($cg - $green) <= $tolerance
		       && abs($cb - $blue) <= $tolerance, $comment)) {
    $builder->diag(<<END_DIAG);
Color out of tolerance ($tolerance):
  Red: expected $red vs received $cr
Green: expected $green vs received $cg
 Blue: expected $blue vs received $cb
END_DIAG
    return;
  }

  return 1;
}

sub is_color4($$$$$$) {
  my ($color, $red, $green, $blue, $alpha, $comment) = @_;

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cr, $cg, $cb, $ca) = $color->rgba;
  unless ($builder->ok($cr == $red && $cg == $green && $cb == $blue 
		       && $ca == $alpha, $comment)) {
    $builder->diag(<<END_DIAG);
Color mismatch:
  Red: $cr vs $red
Green: $cg vs $green
 Blue: $cb vs $blue
Alpha: $ca vs $alpha
END_DIAG
    return;
  }

  return 1;
}

sub is_fcolor4($$$$$$;$) {
  my ($color, $red, $green, $blue, $alpha, $comment_or_diff, $comment_or_undef) = @_;
  my ($comment, $mindiff);
  if (defined $comment_or_undef) {
    ( $mindiff, $comment ) = ( $comment_or_diff, $comment_or_undef )
  }
  else {
    ( $mindiff, $comment ) = ( 0.001, $comment_or_diff )
  }

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cr, $cg, $cb, $ca) = $color->rgba;
  unless ($builder->ok(abs($cr - $red) <= $mindiff
		       && abs($cg - $green) <= $mindiff
		       && abs($cb - $blue) <= $mindiff
		       && abs($ca - $alpha) <= $mindiff, $comment)) {
    $builder->diag(<<END_DIAG);
Color mismatch:
  Red: $cr vs $red
Green: $cg vs $green
 Blue: $cb vs $blue
Alpha: $ca vs $alpha
END_DIAG
    return;
  }

  return 1;
}

sub is_fcolor1($$$;$) {
  my ($color, $grey, $comment_or_diff, $comment_or_undef) = @_;
  my ($comment, $mindiff);
  if (defined $comment_or_undef) {
    ( $mindiff, $comment ) = ( $comment_or_diff, $comment_or_undef )
  }
  else {
    ( $mindiff, $comment ) = ( 0.001, $comment_or_diff )
  }

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cgrey) = $color->rgba;
  unless ($builder->ok(abs($cgrey - $grey) <= $mindiff, $comment)) {
    print <<END_DIAG;
Color mismatch:
  Gray: $cgrey vs $grey
END_DIAG
    return;
  }

  return 1;
}

sub is_fcolor3($$$$$;$) {
  my ($color, $red, $green, $blue, $comment_or_diff, $comment_or_undef) = @_;
  my ($comment, $mindiff);
  if (defined $comment_or_undef) {
    ( $mindiff, $comment ) = ( $comment_or_diff, $comment_or_undef )
  }
  else {
    ( $mindiff, $comment ) = ( 0.001, $comment_or_diff )
  }

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cr, $cg, $cb) = $color->rgba;
  unless ($builder->ok(abs($cr - $red) <= $mindiff
		       && abs($cg - $green) <= $mindiff
		       && abs($cb - $blue) <= $mindiff, $comment)) {
    $builder->diag(<<END_DIAG);
Color mismatch:
  Red: $cr vs $red
Green: $cg vs $green
 Blue: $cb vs $blue
END_DIAG
    return;
  }

  return 1;
}

sub is_color1($$$) {
  my ($color, $grey, $comment) = @_;

  my $builder = Test::Builder->new;

  unless (defined $color) {
    $builder->ok(0, $comment);
    $builder->diag("color is undef");
    return;
  }
  unless ($color->can('rgba')) {
    $builder->ok(0, $comment);
    $builder->diag("color is not a color object");
    return;
  }

  my ($cgrey) = $color->rgba;
  unless ($builder->ok($cgrey == $grey, $comment)) {
    $builder->diag(<<END_DIAG);
Color mismatch:
  Grey: $grey vs $cgrey
END_DIAG
    return;
  }

  return 1;
}

sub test_image_raw {
  my $green=Imager::i_color_new(0,255,0,255);
  my $blue=Imager::i_color_new(0,0,255,255);
  my $red=Imager::i_color_new(255,0,0,255);
  
  my $img=Imager::ImgRaw::new(150,150,3);
  
  Imager::i_box_filled($img,70,25,130,125,$green);
  Imager::i_box_filled($img,20,25,80,125,$blue);
  Imager::i_arc($img,75,75,30,0,361,$red);
  Imager::i_conv($img,[0.1, 0.2, 0.4, 0.2, 0.1]);

  $img;
}

sub test_image {
  my $green = Imager::Color->new(0, 255, 0, 255);
  my $blue  = Imager::Color->new(0, 0, 255, 255);
  my $red   = Imager::Color->new(255, 0, 0, 255);
  my $img = Imager->new(xsize => 150, ysize => 150);
  $img->box(filled => 1, color => $green, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $blue,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $red);
  $img->filter(type => 'conv', coef => [ 0.1, 0.2, 0.4, 0.2, 0.1 ]);

  $img;
}

sub test_image_16 {
  my $green = Imager::Color->new(0, 255, 0, 255);
  my $blue  = Imager::Color->new(0, 0, 255, 255);
  my $red   = Imager::Color->new(255, 0, 0, 255);
  my $img = Imager->new(xsize => 150, ysize => 150, bits => 16);
  $img->box(filled => 1, color => $green, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $blue,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $red);
  $img->filter(type => 'conv', coef => [ 0.1, 0.2, 0.4, 0.2, 0.1 ]);

  $img;
}

sub test_image_double {
  my $green = Imager::Color->new(0, 255, 0, 255);
  my $blue  = Imager::Color->new(0, 0, 255, 255);
  my $red   = Imager::Color->new(255, 0, 0, 255);
  my $img = Imager->new(xsize => 150, ysize => 150, bits => 'double');
  $img->box(filled => 1, color => $green, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $blue,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $red);
  $img->filter(type => 'conv', coef => [ 0.1, 0.2, 0.4, 0.2, 0.1 ]);

  $img;
}

sub test_image_gray {
  my $g50 = Imager::Color->new(128, 128, 128);
  my $g30  = Imager::Color->new(76, 76, 76);
  my $g70   = Imager::Color->new(178, 178, 178);
  my $img = Imager->new(xsize => 150, ysize => 150, channels => 1);
  $img->box(filled => 1, color => $g50, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $g30,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $g70);
  $img->filter(type => 'conv', coef => [ 0.1, 0.2, 0.4, 0.2, 0.1 ]);

  return $img;
}

sub test_image_gray_16 {
  my $g50 = Imager::Color->new(128, 128, 128);
  my $g30  = Imager::Color->new(76, 76, 76);
  my $g70   = Imager::Color->new(178, 178, 178);
  my $img = Imager->new(xsize => 150, ysize => 150, channels => 1, bits => 16);
  $img->box(filled => 1, color => $g50, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $g30,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $g70);
  $img->filter(type => 'conv', coef => [ 0.1, 0.2, 0.4, 0.2, 0.1 ]);

  return $img;
}

sub test_image_mono {
  require Imager::Fill;
  my $fh = Imager::Fill->new(hatch => 'check1x1');
  my $img = Imager->new(xsize => 150, ysize => 150, type => "paletted");
  my $black = Imager::Color->new(0, 0, 0);
  my $white = Imager::Color->new(255, 255, 255);
  $img->addcolors(colors => [ $black, $white ]);
  $img->box(fill => $fh, box => [ 70, 24, 130, 124 ]);
  $img->box(filled => 1, color => $white,  box => [ 20, 26, 80, 126 ]);
  $img->arc(x => 75, y => 75, r => 30, color => $black, aa => 0);

  return $img;
}

my %name_to_sub =
  (
   basic => \&test_image,
   basic16 => \&test_image_16,
   basic_double => \&test_image_double,
   gray => \&test_image_gray,
   gray16 => \&test_image_gray_16,
   mono => \&test_image_mono,
  );

sub test_image_named {
  my $name = shift
    or croak("No name supplied to test_image_named()");
  my $sub = $name_to_sub{$name}
    or croak("Unknown name $name supplied to test_image_named()");

  return $sub->();
}

sub _low_image_diff_check {
  my ($left, $right, $comment) = @_;

  my $builder = Test::Builder->new;

  unless (defined $left) {
    $builder->ok(0, $comment);
    $builder->diag("left is undef");
    return;
  } 
  unless (defined $right) {
    $builder->ok(0, $comment);
    $builder->diag("right is undef");
    return;
  }
  unless ($left->{IMG}) {
    $builder->ok(0, $comment);
    $builder->diag("left image has no low level object");
    return;
  }
  unless ($right->{IMG}) {
    $builder->ok(0, $comment);
    $builder->diag("right image has no low level object");
    return;
  }
  unless ($left->getwidth == $right->getwidth) {
    $builder->ok(0, $comment);
    $builder->diag("left width " . $left->getwidth . " vs right width " 
                   . $right->getwidth);
    return;
  }
  unless ($left->getheight == $right->getheight) {
    $builder->ok(0, $comment);
    $builder->diag("left height " . $left->getheight . " vs right height " 
                   . $right->getheight);
    return;
  }
  unless ($left->getchannels == $right->getchannels) {
    $builder->ok(0, $comment);
    $builder->diag("left channels " . $left->getchannels . " vs right channels " 
                   . $right->getchannels);
    return;
  }

  return 1;
}

sub is_image_similar($$$$) {
  my ($left, $right, $limit, $comment) = @_;

  {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    _low_image_diff_check($left, $right, $comment)
      or return;
  }

  my $builder = Test::Builder->new;

  my $diff = Imager::i_img_diff($left->{IMG}, $right->{IMG});
  if ($diff > $limit) {
    $builder->ok(0, $comment);
    $builder->diag("image data difference > $limit - $diff");
   
    if ($limit == 0) {
      # find the first mismatch
      PIXELS:
      for my $y (0 .. $left->getheight()-1) {
	for my $x (0.. $left->getwidth()-1) {
	  my @lsamples = $left->getsamples(x => $x, y => $y, width => 1);
	  my @rsamples = $right->getsamples(x => $x, y => $y, width => 1);
          if ("@lsamples" ne "@rsamples") {
            $builder->diag("first mismatch at ($x, $y) - @lsamples vs @rsamples");
            last PIXELS;
          }
	}
      }
    }

    return;
  }
  
  return $builder->ok(1, $comment);
}

sub is_image($$$) {
  my ($left, $right, $comment) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  return is_image_similar($left, $right, 0, $comment);
}

sub is_imaged($$$;$) {
  my $epsilon = Imager::i_img_epsilonf();
  if (@_ > 3) {
    ($epsilon) = splice @_, 2, 1;
  }

  my ($left, $right, $comment) = @_;

  {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    _low_image_diff_check($left, $right, $comment)
      or return;
  }

  my $builder = Test::Builder->new;

  my $same = Imager::i_img_samef($left->{IMG}, $right->{IMG}, $epsilon, $comment);
  if (!$same) {
    $builder->ok(0, $comment);
    $builder->diag("images different");

    # find the first mismatch
  PIXELS:
    for my $y (0 .. $left->getheight()-1) {
      for my $x (0.. $left->getwidth()-1) {
	my @lsamples = $left->getsamples(x => $x, y => $y, width => 1, type => "float");
	my @rsamples = $right->getsamples(x => $x, y => $y, width => 1, type => "float");
	if ("@lsamples" ne "@rsamples") {
	  $builder->diag("first mismatch at ($x, $y) - @lsamples vs @rsamples");
	  last PIXELS;
	}
      }
    }

    return;
  }
  
  return $builder->ok(1, $comment);
}

sub isnt_image {
  my ($left, $right, $comment) = @_;

  my $builder = Test::Builder->new;

  my $diff = Imager::i_img_diff($left->{IMG}, $right->{IMG});

  return $builder->ok($diff, "$comment");
}

sub image_bounds_checks {
  my $im = shift;

  my $builder = Test::Builder->new;

  $builder->ok(!$im->getpixel(x => -1, y => 0), 'bounds check get (-1, 0)');
  $builder->ok(!$im->getpixel(x => 10, y => 0), 'bounds check get (10, 0)');
  $builder->ok(!$im->getpixel(x => 0, y => -1), 'bounds check get (0, -1)');
  $builder->ok(!$im->getpixel(x => 0, y => 10), 'bounds check get (0, 10)');
  $builder->ok(!$im->getpixel(x => -1, y => 0), 'bounds check get (-1, 0) float');
  $builder->ok(!$im->getpixel(x => 10, y => 0), 'bounds check get (10, 0) float');
  $builder->ok(!$im->getpixel(x => 0, y => -1), 'bounds check get (0, -1) float');
  $builder->ok(!$im->getpixel(x => 0, y => 10), 'bounds check get (0, 10) float');
  my $black = Imager::Color->new(0, 0, 0);
  require Imager::Color::Float;
  my $blackf = Imager::Color::Float->new(0, 0, 0);
  $builder->ok($im->setpixel(x => -1, y => 0, color => $black) == 0,
	       'bounds check set (-1, 0)');
  $builder->ok($im->setpixel(x => 10, y => 0, color => $black) == 0,
	       'bounds check set (10, 0)');
  $builder->ok($im->setpixel(x => 0, y => -1, color => $black) == 0,
	       'bounds check set (0, -1)');
  $builder->ok($im->setpixel(x => 0, y => 10, color => $black) == 0,
	       'bounds check set (0, 10)');
  $builder->ok($im->setpixel(x => -1, y => 0, color => $blackf) == 0,
	       'bounds check set (-1, 0) float');
  $builder->ok($im->setpixel(x => 10, y => 0, color => $blackf) == 0,
	       'bounds check set (10, 0) float');
  $builder->ok($im->setpixel(x => 0, y => -1, color => $blackf) == 0,
	       'bounds check set (0, -1) float');
  $builder->ok($im->setpixel(x => 0, y => 10, color => $blackf) == 0,
	       'bounds check set (0, 10) float');
}

sub test_colorf_gpix {
  my ($im, $x, $y, $expected, $epsilon, $comment) = @_;

  my $builder = Test::Builder->new;
  
  defined $comment or $comment = '';

  my $c = Imager::i_gpixf($im, $x, $y);
  unless ($c) {
    $builder->ok(0, "$comment - retrieve color at ($x,$y)");
    return;
  }
  unless ($builder->ok(colorf_cmp($c, $expected, $epsilon) == 0,
	     "$comment - got right color ($x, $y)")) {
    my @c = $c->rgba;
    my @exp = $expected->rgba;
    $builder->diag(<<EOS);
# got: ($c[0], $c[1], $c[2])
# expected: ($exp[0], $exp[1], $exp[2])
EOS
  }
  1;
}

sub test_color_gpix {
  my ($im, $x, $y, $expected, $comment) = @_;

  my $builder = Test::Builder->new;
  
  defined $comment or $comment = '';
  my $c = Imager::i_get_pixel($im, $x, $y);
  unless ($c) {
    $builder->ok(0, "$comment - retrieve color at ($x,$y)");
    return;
  }
  unless ($builder->ok(color_cmp($c, $expected) == 0,
     "got right color ($x, $y)")) {
    my @c = $c->rgba;
    my @exp = $expected->rgba;
    $builder->diag(<<EOS);
# got: ($c[0], $c[1], $c[2])
# expected: ($exp[0], $exp[1], $exp[2])
EOS
    return;
  }

  return 1;
}

sub test_colorf_glin {
  my ($im, $x, $y, $pels, $comment) = @_;

  my $builder = Test::Builder->new;
  
  my @got = Imager::i_glinf($im, $x, $x+@$pels, $y);
  @got == @$pels
    or return $builder->is_num(scalar(@got), scalar(@$pels), "$comment - pixels retrieved");
  
  return $builder->ok(!grep(colorf_cmp($pels->[$_], $got[$_], 0.005), 0..$#got),
     "$comment - check colors ($x, $y)");
}

sub colorf_cmp {
  my ($c1, $c2, $epsilon) = @_;

  defined $epsilon or $epsilon = 0;

  my @s1 = $c1->rgba;
  my @s2 = $c2->rgba;

  # print "# (",join(",", @s1[0..2]),") <=> (",join(",", @s2[0..2]),")\n";
  return abs($s1[0]-$s2[0]) >= $epsilon && $s1[0] <=> $s2[0] 
    || abs($s1[1]-$s2[1]) >= $epsilon && $s1[1] <=> $s2[1]
      || abs($s1[2]-$s2[2]) >= $epsilon && $s1[2] <=> $s2[2];
}

sub color_cmp {
  my ($c1, $c2) = @_;

  my @s1 = $c1->rgba;
  my @s2 = $c2->rgba;

  return $s1[0] <=> $s2[0] 
    || $s1[1] <=> $s2[1]
      || $s1[2] <=> $s2[2];
}

# these test the action of the channel mask on the image supplied
# which should be an OO image.
sub mask_tests {
  my ($im, $epsilon) = @_;

  my $builder = Test::Builder->new;

  defined $epsilon or $epsilon = 0;

  # we want to check all four of ppix() and plin(), ppix() and plinf()
  # basic test procedure:
  #   first using default/all 1s mask, set to white
  #   make sure we got white
  #   set mask to skip a channel, set to grey
  #   make sure only the right channels set

  print "# channel mask tests\n";
  # 8-bit color tests
  my $white = Imager::NC(255, 255, 255);
  my $grey = Imager::NC(128, 128, 128);
  my $white_grey = Imager::NC(128, 255, 128);

  print "# with ppix\n";
  $builder->ok($im->setmask(mask=>~0), "set to default mask");
  $builder->ok($im->setpixel(x=>0, 'y'=>0, color=>$white), "set to white all channels");
  test_color_gpix($im->{IMG}, 0, 0, $white, "ppix");
  $builder->ok($im->setmask(mask=>0xF-0x2), "set channel to exclude channel1");
  $builder->ok($im->setpixel(x=>0, 'y'=>0, color=>$grey), "set to grey, no channel 2");
  test_color_gpix($im->{IMG}, 0, 0, $white_grey, "ppix masked");

  print "# with plin\n";
  $builder->ok($im->setmask(mask=>~0), "set to default mask");
  $builder->ok($im->setscanline(x=>0, 'y'=>1, pixels => [$white]), 
     "set to white all channels");
  test_color_gpix($im->{IMG}, 0, 1, $white, "plin");
  $builder->ok($im->setmask(mask=>0xF-0x2), "set channel to exclude channel1");
  $builder->ok($im->setscanline(x=>0, 'y'=>1, pixels=>[$grey]), 
     "set to grey, no channel 2");
  test_color_gpix($im->{IMG}, 0, 1, $white_grey, "plin masked");

  # float color tests
  my $whitef = Imager::NCF(1.0, 1.0, 1.0);
  my $greyf = Imager::NCF(0.5, 0.5, 0.5);
  my $white_greyf = Imager::NCF(0.5, 1.0, 0.5);

  print "# with ppixf\n";
  $builder->ok($im->setmask(mask=>~0), "set to default mask");
  $builder->ok($im->setpixel(x=>0, 'y'=>2, color=>$whitef), "set to white all channels");
  test_colorf_gpix($im->{IMG}, 0, 2, $whitef, $epsilon, "ppixf");
  $builder->ok($im->setmask(mask=>0xF-0x2), "set channel to exclude channel1");
  $builder->ok($im->setpixel(x=>0, 'y'=>2, color=>$greyf), "set to grey, no channel 2");
  test_colorf_gpix($im->{IMG}, 0, 2, $white_greyf, $epsilon, "ppixf masked");

  print "# with plinf\n";
  $builder->ok($im->setmask(mask=>~0), "set to default mask");
  $builder->ok($im->setscanline(x=>0, 'y'=>3, pixels => [$whitef]), 
     "set to white all channels");
  test_colorf_gpix($im->{IMG}, 0, 3, $whitef, $epsilon, "plinf");
  $builder->ok($im->setmask(mask=>0xF-0x2), "set channel to exclude channel1");
  $builder->ok($im->setscanline(x=>0, 'y'=>3, pixels=>[$greyf]), 
     "set to grey, no channel 2");
  test_colorf_gpix($im->{IMG}, 0, 3, $white_greyf, $epsilon, "plinf masked");

}

sub std_font_test_count {
  return 21;
}

sub std_font_tests {
  my ($opts) = @_;

  my $font = $opts->{font}
    or carp "Missing font parameter";

  my $name_font = $opts->{glyph_name_font} || $font;

  my $has_chars = $opts->{has_chars} || [ 1, '', 1 ];

  my $glyph_names = $opts->{glyph_names} || [ "A", undef, "A" ];

 SKIP:
  { # check magic is handled correctly
    # https://rt.cpan.org/Ticket/Display.html?id=83438
    skip("no native UTF8 support in this version of perl", 11) 
      unless $] >= 5.006;
    skip("overloading handling of magic is broken in this version of perl", 11)
      unless $] >= 5.008;
    Imager->log("utf8 magic tests\n");
    my $over = bless {}, "Imager::Test::OverUtf8";
    my $text = "A".chr(0x2010)."A";
    my $white = Imager::Color->new("#FFF");
    my $base_draw = Imager->new(xsize => 80, ysize => 20);
    ok($base_draw->string(font => $font,
			  text => $text,
			  x => 2,
			  y => 18,
			  size => 15,
			  color => $white,
			  aa => 1),
       "magic: make a base image");
    my $test_draw = Imager->new(xsize => 80, ysize => 20);
    ok($test_draw->string(font => $font,
			  text => $over,
			  x => 2,
			  y => 18,
			  size => 15,
			  color => $white,
			  aa => 1),
       "magic: draw with overload");
    is_image($base_draw, $test_draw, "check they match");
    if ($opts->{files}) {
      $test_draw->write(file => "testout/utf8tdr.ppm");
      $base_draw->write(file => "testout/utf8bdr.ppm");
    }

    my $base_cp = Imager->new(xsize => 80, ysize => 20);
    $base_cp->box(filled => 1, color => "#808080");
    my $test_cp = $base_cp->copy;
    ok($base_cp->string(font => $font,
			text => $text,
			y => 2,
			y => 18,
			size => 16,
			channel => 2,
			aa => 1),
       "magic: make a base image (channel)");
    Imager->log("magic: draw to channel with overload\n");
    ok($test_cp->string(font => $font,
			text => $over,
			y => 2,
			y => 18,
			size => 16,
			channel => 2,
			aa => 1),
       "magic: draw with overload (channel)");
    is_image($test_cp, $base_cp, "check they match");
    if ($opts->{files}) {
      $test_cp->write(file => "testout/utf8tcp.ppm");
      $base_cp->write(file => "testout/utf8bcp.ppm");
    }

  SKIP:
    {
      Imager->log("magic: has_chars\n");
      $font->can("has_chars")
	or skip "No has_chars aupport", 2;
      is_deeply([ $font->has_chars(string => $text) ], $has_chars,
		"magic: has_chars with normal utf8 text");
      is_deeply([ $font->has_chars(string => $over) ], $has_chars,
		"magic: has_chars with magic utf8 text");
    }

    Imager->log("magic: bounding_box\n");
    my @base_bb = $font->bounding_box(string => $text, size => 30);
    is_deeply([ $font->bounding_box(string => $over, size => 30) ],
	      \@base_bb,
	      "check bounding box magic");

  SKIP:
    {
      $font->can_glyph_names
	or skip "No glyph_names", 2;
      Imager->log("magic: glyph_names\n");
      my @text_names = $name_font->glyph_names(string => $text, reliable_only => 0);
      is_deeply(\@text_names, $glyph_names,
		"magic: glyph_names with normal utf8 text");
      my @over_names = $name_font->glyph_names(string => $over, reliable_only => 0);
      is_deeply(\@over_names, $glyph_names,
		"magic: glyph_names with magic utf8 text");
    }
  }

  { # invalid UTF8 handling at the OO level
    my $im = Imager->new(xsize => 80, ysize => 20);
    my $bad_utf8 = pack("C", 0xC0);
    Imager->_set_error("");
    ok(!$im->string(font => $font, size => 1, text => $bad_utf8, utf8 => 1,
		    y => 18, x => 2),
       "drawing invalid utf8 should fail");
    is($im->errstr, "invalid UTF8 character", "check error message");
    Imager->_set_error("");
    ok(!$im->string(font => $font, size => 1, text => $bad_utf8, utf8 => 1,
		    y => 18, x => 2, channel => 1),
       "drawing invalid utf8 should fail (channel)");
    is($im->errstr, "invalid UTF8 character", "check error message");
    Imager->_set_error("");
    ok(!$font->bounding_box(string => $bad_utf8, size => 30, utf8 => 1),
       "bounding_box() bad utf8 should fail");
    is(Imager->errstr, "invalid UTF8 character", "check error message");
  SKIP:
    {
      $font->can_glyph_names
	or skip "No glyph_names support", 2;
      Imager->_set_error("");
      is_deeply([ $font->glyph_names(string => $bad_utf8, utf8 => 1) ],
		[ ],
		"glyph_names returns empty list for bad string");
      is(Imager->errstr, "invalid UTF8 character", "check error message");
    }
  SKIP:
    {
      $font->can("has_chars")
	or skip "No has_chars support", 2;
      Imager->_set_error("");
      is_deeply([ $font->has_chars(string => $bad_utf8, utf8 => 1) ],
		[ ],
		"has_chars returns empty list for bad string");
      is(Imager->errstr, "invalid UTF8 character", "check error message");
    }
  }
}

sub is_arrayf($$$;$) {
  my ($left, $right, $note, $tolerance) = @_;

  defined $tolerance or $tolerance = 0.00001;

  my $builder = Test::Builder->new;

  unless (@$left == @$right) {
    $builder->ok(0, $note);
    $builder->diag("left of \@\$left and \@\$right do not match");
    return;
  }

  my $good = 1;
  my @errors;
  for my $i (0.. $#$left) {
    if (defined $left->[$i]) {
      if (defined $right->[$i]) {
	my $diff = abs($left->[$i] - $right->[$i]);
	unless ($diff <= $tolerance) {
	  push @errors, "mismatch index $i: $left->[$i] vs $right->[$i] -> $diff";
	  $good = 0;
	}
      }
      else {
	push @errors, "mismatch index $i: $left->[$i] vs undef";
	$good = 0;
      }
    }
    elsif (defined $right->[$i]) {
      push @errors, "mismatch index $i: undef vs $right->[$i] undef";
      $good = 0;
    }
  }
  $builder->ok($good, $note);
  $builder->diag($_) for @errors;

  return $good;
}

sub std_image_tests_count {
  my ($opts) = @_;

  my $channels = $opts->{models} || [ qw(gray graya rgb rgba) ];

  return 2 + ( 74 * @$channels );
}

sub std_image_tests {
  my ($opts) = @_;

  my $bits = $opts->{bits}
    or croak "Missing bits parameter";

  my $models = $opts->{models} || [ qw(gray graya rgb rgba) ];

  my @ten_zeros = (0) x 10;

  is(to_linear_srgb(0), 0, "check to_linear(0)");
  is(to_linear_srgb(255), 0xFFFF, "check to_linear(255)");

  my @test_colors =
    (
     [ 255, 128, 0,  255 ],
     [ 192, 128, 64, 128 ],
    );

  for my $model (@$models) {
    print "# model $model\n";
    my $im = Imager->new(xsize => 10, ysize => 10, model => $model);
    my $alpha_ch = $im->alphachannel;
    my $col_channels = $im->colorchannels;
    my $channel_count = $col_channels;
    ++$channel_count if $alpha_ch;
    my @colors;
    my @samples;
    my @samples_alpha;
    my @alphas;
    for my $color (@test_colors) {
      my @ch = @{$color}[0 .. $col_channels-1 ];
      push @samples, @ch;
      push @samples_alpha, @ch;
      if ($alpha_ch) {
	my $alpha = $color->[3];
	push @ch, $alpha;
	push @alphas, $alpha;
	push @samples_alpha, $alpha;
      }
      push @colors, \@ch;
    }
    my @channels = ( 0 .. $channel_count-1 );
    ok($im->setpixel(x => 0, y => 0, color => { channels => $colors[0] }),
       "set a normal spread of values at (0,0)")
      or diag "$model: set first pixel to (" . join(", ", @{$colors[0]}) . "): ".$im->errstr;
    ok($im->setpixel(x => 1, y => 0, color => { channels => $colors[1] }),
       "set a normal spread of values at (1,0)");
    my $sl = $im->getsamples(y => 0, width => 2, scale => "linear",
			     channels => \@channels)
      or diag "getsamples: ", Imager->_error_as_msg;
    my @cmp_sl = ( map to_linear_srgb($_), @samples );
    if ($alpha_ch) {
      splice(@cmp_sl, $col_channels, 0, 65535);
      push @cmp_sl, 128 * 0x101;
    }
    is_deeply([ unpack("S*", $sl) ], \@cmp_sl,
	      "check linear result (scalar)");
    my @test_sl = $im->getsamples(y => 0, width => 2, scale => "linear",
				  channels => $channel_count);
    is_deeply(\@test_sl, \@cmp_sl,
	      "check linear result (list)");
    is($im->setsamples(y => 1, data => $sl, channels => $channel_count,
		       scale => "linear"), $channel_count * 2,
       "set the packed linear samples on a new line");
    my @cmp_samps_gamma = @samples_alpha;
    is_deeply([ $im->getsamples(y => 1, width => 2) ], \@cmp_samps_gamma,
	      "check we got back our original gamma values");
    ok($im->setsamples(y => 2, data => \@test_sl, channels => $channel_count,
		       scale => "linear"),
       "set the unpacked linear samples on a new line");
    is_deeply([ $im->getsamples(y => 2, width => 2) ], \@cmp_samps_gamma,
	      "check we got back our original gamma values");

    my @fsamps = $im->getsamples(y => 0, width => 2,
				 scale => "linear", type => "float");
    my @fcmp_sl = map $_ / 65535.0, @cmp_sl;
    is_arrayf(\@fsamps, \@fcmp_sl,
	      "check linear float samples");
    is($im->setsamples(y => 3, data => \@fcmp_sl,
		       channels => $channel_count, scale => "linear", type => "float"),
       scalar @fsamps, "set linear float samples");
    my @gsamps = $im->getsamples(y => 3, scale => "linear", type => "float",
				 width => 2);
    is_arrayf(\@gsamps, \@fcmp_sl, "check samples were set");
    my @gsamp_gamma = $im->getsamples(y => 3, width => 2);
    is_deeply(\@gsamp_gamma, \@cmp_samps_gamma,
	      "make sure the stored samples are what we expect");

    # explicit channel lists
    is($im->setsamples(y => 4, data => \@cmp_sl, width => 2,
		       channels => \@channels, scale => "linear"),
       $channel_count * 2,
       "set linear samples (explicit channels)");
    @gsamps = $im->getsamples(y => 4, scale => "linear",
			      width => 2, channels => \@channels);
    is_deeply(\@gsamps, \@cmp_sl, "check samples were set (explicit channels)");

    is($im->setsamples(y => 5, data => \@fcmp_sl, width => 2,
		       channels => \@channels, scale => "linear",
		       type => "float"), $channel_count * 2,
       "set linear samples (float, explicit channels)");
    @gsamps = $im->getsamples(y => 5, scale => "linear", type => "float",
			      width => 2, channels => \@channels);
    is_arrayf(\@gsamps, \@fcmp_sl, "check samples were set (float, explicit channels)");

    # masks
    my $oldmask = $im->getmask;
    ok($im->setmask(mask => 13), "set the mask to not cover all channels");
    my @cmp_sl_masked = ( map $_ % $channel_count == 1 ? 0 : $cmp_sl[$_], 0 .. $#cmp_sl );
    is($im->setsamples(y => 6, data => \@cmp_sl, width => 2,
		       channels => \@channels, scale => "linear"),
       $channel_count * 2,
       "set linear samples (explicit channels, masked)");
    @gsamps = $im->getsamples(y => 6, width => 2,
			      channels => \@channels, scale => "linear");
    is_deeply(\@gsamps, \@cmp_sl_masked,
	      "check linear samples (explicit channels, masked)");

    my @fcmp_sl_masked = ( map $_ % $channel_count == 1 ? 0 : $fcmp_sl[$_], 0 .. $#fcmp_sl );
    is($im->setsamples(y => 7, data => \@fcmp_sl, width => 2, type => "float",
		       channels => \@channels, scale => "linear"),
       $channel_count * 2,
       "set linear float samples (explicit channels, masked)");
    @gsamps = $im->getsamples(y => 7, width => 2, type => "float",
			      channels => \@channels, scale => "linear");
    is_arrayf(\@gsamps, \@fcmp_sl_masked,
	      "check linear float samples (explicit channels, masked)");
    $im->setmask(mask => $oldmask);

    # fetch to target
    my @target;
    is($im->getsamples(y => 0, width => 2, scale => "linear", target => \@target),
       $channel_count * 2,
       "fetch linear samples to target");
    is_deeply(\@target, \@cmp_sl, "check correct samples in target");
    @target = ();
    is($im->getsamples(y => 0, width => 2, scale => "linear",
		       target => \@target, offset => 2),
       $channel_count * 2,
       "fetch linear to target with offset");
    is_deeply(\@target, [ (undef) x 2, @cmp_sl ],
	      "check offset honored");
    @target = ();

    is($im->getsamples(y => 0, width => 2, scale => "linear",
		       target => \@target, type => "float"),
       $channel_count * 2,
       "fetch linear samples to target");
    is_arrayf(\@target, \@fcmp_sl, "check correct samples in target");
    @target = ();
    is($im->getsamples(y => 0, width => 2, scale => "linear",
		       target => \@target, offset => 2, type => "float"),
       $channel_count * 2,
       "fetch linear to target with offset");
    is_arrayf(\@target, [ (undef) x 2, @fcmp_sl ],
	      "check offset honored");

    # range checks (16-bit)
    # set
    is($im->setsamples(y => -1, data => \@gsamps, scale => "linear"),
       undef,
       "set linear samples to y = -1");
    is($im->errstr, "Image position outside of image",
       "check error message (y = -1)");
    is($im->setsamples(y => 10, data => \@gsamps, scale => "linear"),
       undef,
       "set linear samples to y = 10");
    is($im->errstr, "Image position outside of image",
       "check error message (y = 10)");
    is($im->setsamples(y => 9, x => -1, data => \@gsamps, scale => "linear"),
       undef,
       "set linear samples to x = -1");
    is($im->errstr, "Image position outside of image",
       "check error message (x = -1)");
    is($im->setsamples(y => 9, x => 10, data => \@gsamps, scale => "linear"),
       undef,
       "set linear samples to x = 10");
    is($im->errstr, "Image position outside of image",
       "check error message (x = 10)");

    is($im->setsamples(y => 9, data => \@gsamps, channels => [-1],
		       scale => "linear"), undef,
       "set negative channel");
    is($im->errstr, "No channel -1 in this image",
       "check error message (negative channel)");
    is($im->setsamples(y => 9, data => \@gsamps, channels => [$channel_count],
		       scale => "linear"), undef,
       "set too high channel");
    is($im->errstr, "No channel $channel_count in this image",
       "check error message (too high channel)");

    is($im->setsamples(y => 9, x => 1, data => \@ten_zeros, channels => [0],
		       scale => "linear", width => 10),
       9,
       "set check right-side limit");

    is($im->setsamples(y => 9, data => \@gsamps, channels => -1,
		       scale => "linear"), undef,
       "set negative channel count");
    is($im->setsamples(y => 9, data => \@gsamps, channels => 5,
		       scale => "linear"), undef,
       "set too high channel count");

    # get
    is($im->getsamples(y => -1, data => \@gsamps, scale => "linear"),
       undef,
       "get linear samples from y = -1");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "Image position outside of image",
	 "check error message (y = -1)");
    }
    is($im->getsamples(y => 10, data => \@gsamps, scale => "linear"),
       undef,
       "get linear samples from y = 10");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "Image position outside of image",
	 "check error message (y = 10)");
    }
    is($im->getsamples(y => 9, x => -1, data => \@gsamps, scale => "linear"),
       undef,
       "get linear samples to x = -1");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "Image position outside of image",
	 "check error message (x = -1)");
    }
    is($im->getsamples(y => 9, x => 10, data => \@gsamps, scale => "linear"),
       undef,
       "get linear samples to x = 10");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "Image position outside of image",
	 "check error message (x = 10)");
    }

    is($im->getsamples(y => 9, data => \@gsamps, channels => [-1],
		       scale => "linear"), undef,
       "get negative channel");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "No channel -1 in this image",
	 "check error message (negative channel)");
    }
    is($im->getsamples(y => 9, data => \@gsamps, channels => [$channel_count],
		       scale => "linear"), undef,
       "get too high channel");
    {
      local $TODO = "getsamples() doesn't do error reporting";
      is($im->errstr, "No channel $channel_count in this image",
	 "check error message (too high channel)");
    }

    is_deeply([ $im->getsamples(y => 9, x => 1, channels => [0],
				scale => "linear", width => 10) ],
	      [ (0) x 9 ],
	      "get check right-side limit");

    is($im->getsamples(y => 9, data => \@gsamps, channels => -1,
		       scale => "linear"), undef,
       "get negative channel count");
    is($im->getsamples(y => 9, data => \@gsamps, channels => 5,
		       scale => "linear"), undef,
       "get too high channel count");

    # range checks (float)
    is($im->setsamples(y => -1, data => \@fcmp_sl, scale => "linear", type => "float"),
       undef,
       "set linear samples to y = -1 (float)");
    is($im->errstr, "Image position outside of image",
       "check error message (y = -1) (float)");
    is($im->setsamples(y => 10, data => \@fcmp_sl, scale => "linear", type => "float"),
       undef,
       "set linear samples to y = 10 (float)");
    is($im->errstr, "Image position outside of image",
       "check error message (y = 10) (float)");
    is($im->setsamples(y => 9, x => -1, data => \@fcmp_sl, scale => "linear", type => "float"),
       undef,
       "set linear samples to x = -1 (float)");
    is($im->errstr, "Image position outside of image",
       "check error message (x = -1) (float)");
    is($im->setsamples(y => 9, x => 10, data => \@fcmp_sl, scale => "linear", type => "float"),
       undef,
       "set linear samples to x = 10 (float)");
    is($im->errstr, "Image position outside of image",
       "check error message (x = 10) (float)");

    is($im->setsamples(y => 9, data => \@gsamps, channels => [-1],
		       scale => "linear", type => "float"), undef,
       "set negative channel (float)");
    is($im->errstr, "No channel -1 in this image",
       "check error message (negative channel)(float)");
    is($im->setsamples(y => 9, data => \@gsamps, channels => [$channel_count],
		       scale => "linear", type => "float"), undef,
       "set too high channel (float)");
    is($im->errstr, "No channel $channel_count in this image",
       "check error message (too high channel)(float)");

    is($im->setsamples(y => 9, x => 1, data => \@ten_zeros, channels => [0],
		       scale => "linear", width => 10, type => "float"),
       9,
       "set check right-side limit (float)");

    is($im->setsamples(y => 9, data => \@gsamps, channels => -1,
		       scale => "linear", type => "float"), undef,
       "negative channel count");
    is($im->setsamples(y => 9, data => \@gsamps, channels => 5,
		       scale => "linear", type => "float"), undef,
       "set too high channel count");
  }
}

sub to_linear_srgb {
  my ($val) = @_;

  return 0+sprintf("%.0f", to_linear_srgbf($val/255.0) * 65535);
}

sub to_linear_srgbf {
  my ($val) = @_;

  my $out;
  if ($val <= 0.04045) {
    $out = $val / 12.92;
  }
  else {
    $out = (($val + 0.055) / (1+0.055)) ** 2.4;
  }

  return $out;
}

package Imager::Test::OverUtf8;
use overload '""' => sub { "A".chr(0x2010)."A" };


1;

__END__

=head1 NAME

Imager::Test - common functions used in testing Imager

=head1 SYNOPSIS

  use Imager::Test 'diff_text_with_nul';
  diff_text_with_nul($test_name, $text1, $text2, @string_options);

=head1 DESCRIPTION

This is a repository of functions used in testing Imager.

Some functions will only be useful in testing Imager itself, while
others should be useful in testing modules that use Imager.

No functions are exported by default.

=head1 FUNCTIONS

=head2 Test functions

=for stopwords OO

=over

=item is_color1($color, $grey, $comment)

Tests if the first channel of $color matches $grey.

=item is_color3($color, $red, $green, $blue, $comment)

Tests if $color matches the given ($red, $green, $blue)

=item is_color4($color, $red, $green, $blue, $alpha, $comment)

Tests if $color matches the given ($red, $green, $blue, $alpha)

=item is_fcolor1($fcolor, $grey, $comment)

=item is_fcolor1($fcolor, $grey, $epsilon, $comment)

Tests if $fcolor's first channel is within $epsilon of ($grey).  For
the first form $epsilon is taken as 0.001.

=item is_fcolor3($fcolor, $red, $green, $blue, $comment)

=item is_fcolor3($fcolor, $red, $green, $blue, $epsilon, $comment)

Tests if $fcolor's channels are within $epsilon of ($red, $green,
$blue).  For the first form $epsilon is taken as 0.001.

=item is_fcolor4($fcolor, $red, $green, $blue, $alpha, $comment)

=item is_fcolor4($fcolor, $red, $green, $blue, $alpha, $epsilon, $comment)

Tests if $fcolor's channels are within $epsilon of ($red, $green,
$blue, $alpha).  For the first form $epsilon is taken as 0.001.

=item is_image($im1, $im2, $comment)

Tests if the 2 images have the same content.  Both images must be
defined, have the same width, height, channels and the same color in
each pixel.  The color comparison is done at 8-bits per pixel.  The
color representation such as direct vs paletted, bits per sample are
not checked.  Equivalent to is_image_similar($im1, $im2, 0, $comment).

=item is_imaged($im, $im2, $comment)

=item is_imaged($im, $im2, $epsilon, $comment)

Tests if the two images have the same content at the double/sample
level.  C<$epsilon> defaults to the platform DBL_EPSILON multiplied by
four.

=item is_image_similar($im1, $im2, $maxdiff, $comment)

Tests if the 2 images have similar content.  Both images must be
defined, have the same width, height and channels.  The cum of the
squares of the differences of each sample are calculated and must be
less than or equal to I<$maxdiff> for the test to pass.  The color
comparison is done at 8-bits per pixel.  The color representation such
as direct vs paletted, bits per sample are not checked.

=item isnt_image($im1, $im2, $comment)

Tests that the two images are different.  For regressions tests where
something (like text output of "0") produced no change, but should
have produced a change.

=item test_colorf_gpix($im, $x, $y, $expected, $epsilon, $comment)

Retrieves the pixel ($x,$y) from the low-level image $im and compares
it to the floating point color $expected, with a tolerance of epsilon.

=item test_color_gpix($im, $x, $y, $expected, $comment)

Retrieves the pixel ($x,$y) from the low-level image $im and compares
it to the floating point color $expected.

=item test_colorf_glin($im, $x, $y, $pels, $comment)

Retrieves the floating point pixels ($x, $y)-[$x+@$pels, $y] from the
low level image $im and compares them against @$pels.

=item is_color_close3($color, $red, $green, $blue, $tolerance, $comment)

Tests if $color's first three channels are within $tolerance of ($red,
$green, $blue).

=item is_arrayf($left, $right, $note)

=item is_arrayf($left, $right, $note, $tolerance)

Compares the length of C<@$left> and C<@$right>, then compares
corresponding array elements for rough equality, controlled by
C<$tolerance>.

Reports a successful test if all matches, fails otherwise.

Reports any mismatches via diag().

=back

=head2 Test suite functions

Functions that perform one or more tests, typically used to test
various parts of Imager's implementation.

=over

=item image_bounds_checks($im)

Attempts to write to various pixel positions outside the edge of the
image to ensure that it fails in those locations.

Any new image type should pass these tests.  Does 16 separate tests.

=item mask_tests($im, $epsilon)

Perform a standard set of mask tests on the OO image $im.  Does 24
separate tests.

=item diff_text_with_nul($test_name, $text1, $text2, @options)

Creates 2 test images and writes $text1 to the first image and $text2
to the second image with the string() method.  Each call adds 3
C<ok>/C<not ok> to the output of the test script.

Extra options that should be supplied include the font and either a
color or channel parameter.

This was explicitly created for regression tests on #21770.

=item std_font_tests({ font => $font })

Perform standard font interface tests.

=item std_font_test_count()

The number of tests performed by std_font_tests().

=item std_image_tests(\%options)

Perform standard tests of images.  This is currently slanted towards
the getsamples() and setsamples() methods, but that will change over
time.

C<%options> can contain the following keys:

=over

=item *

C<bits> - the number of bits to use when creating the images.
Required.

=item *

C<models> - the image color models to check.  Defaults to testing all
of C<gray>, C<graya>, C<rgb> and C<rgba>.

=back

  plan tests => $local_tests + std_image_tests_count({ bits => $bits });
  ...
  std_image_tests({ bits => $bits });

=item std_image_tests_count(\%options)

The number of tests performed by std_image_tests().  Must be supplied
the same options as std_image_tests().

=item to_linear_srgb

=item to_linear_srgbf

Convert a sRGB tone curve sample into a linear sample.

to_linear_srgb() converts an 8-bit sample into a 16-bit sample.

to_linear_srgbf() converts a floating point sample into a floating
point sample.

  my $lin = to_linear_srgb($gam);
  my $linf = to_linear_srgbf($gamf);

=back

=head2 Helper functions

=over

=item test_image_raw()

Returns a 150x150x3 Imager::ImgRaw test image.

=item test_image()

Returns a 150x150x3 8-bit/sample OO test image. Name: C<basic>.

=item test_image_16()

Returns a 150x150x3 16-bit/sample OO test image. Name: C<basic16>

=item test_image_double()

Returns a 150x150x3 double/sample OO test image. Name: C<basic_double>.

=item test_image_gray()

Returns a 150x150 single channel OO test image. Name: C<gray>.

=item test_image_gray_16()

Returns a 150x150 16-bit/sample single channel OO test image. Name:
C<gray16>.

=item test_image_mono()

Returns a 150x150 bilevel image that passes the is_bilevel() test.
Name: C<mono>.

=item test_image_named($name)

Return one of the other test images above based on name.

=item color_cmp($c1, $c2)

Performs an ordering of 3-channel colors (like <=>).

=item colorf_cmp($c1, $c2)

Performs an ordering of 3-channel floating point colors (like <=>).

=back

=head1 AUTHOR

Tony Cook <tony@develop-help.com>

=cut
