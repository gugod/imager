#!perl -w
use strict;
use Imager qw(:all);
use Test::More tests => 86;

init_log("testout/t101jpeg.log",1);

my $green=i_color_new(0,255,0,255);
my $blue=i_color_new(0,0,255,255);
my $red=i_color_new(255,0,0,255);

my $img=Imager::ImgRaw::new(150,150,3);
my $cmpimg=Imager::ImgRaw::new(150,150,3);

i_box_filled($img,70,25,130,125,$green);
i_box_filled($img,20,25,80,125,$blue);
i_arc($img,75,75,30,0,361,$red);
i_conv($img,[0.1, 0.2, 0.4, 0.2, 0.1]);

i_has_format("jpeg") && print "# has jpeg\n";
if (!i_has_format("jpeg")) {
  # previously we'd crash if we tried to save/read an image via the OO
  # interface when there was no jpeg support
 SKIP:
  {
    my $im = Imager->new;
    ok(!$im->read(file=>"testimg/base.jpg"), "should fail to read jpeg");
    cmp_ok($im->errstr, '=~', qr/format 'jpeg' not supported/, "check no jpeg message");
    $im = Imager->new(xsize=>2, ysize=>2);
    ok(!$im->write(file=>"testout/nojpeg.jpg"), "should fail to write jpeg");
    cmp_ok($im->errstr, '=~', qr/format not supported/, "check no jpeg message");
    skip("no jpeg support", 82);
  }
} else {
  open(FH,">testout/t101.jpg") || die "cannot open testout/t101.jpg for writing\n";
  binmode(FH);
  my $IO = Imager::io_new_fd(fileno(FH));
  ok(i_writejpeg_wiol($img,$IO,30), "write jpeg low level");
  close(FH);

  open(FH, "testout/t101.jpg") || die "cannot open testout/t101.jpg\n";
  binmode(FH);
  $IO = Imager::io_new_fd(fileno(FH));
  ($cmpimg,undef) = i_readjpeg_wiol($IO);
  close(FH);

  my $diff = sqrt(i_img_diff($img,$cmpimg))/150*150;
  print "# jpeg average mean square pixel difference: ",$diff,"\n";
  ok($cmpimg, "read jpeg low level");

  ok($diff < 10000, "difference between original and jpeg within bounds");

	Imager::i_log_entry("Starting 4\n", 1);
  my $imoo = Imager->new;
  ok($imoo->read(file=>'testout/t101.jpg'), "read jpeg OO");

  ok($imoo->write(file=>'testout/t101_oo.jpg'), "write jpeg OO");
	Imager::i_log_entry("Starting 5\n", 1);
  my $oocmp = Imager->new;
  ok($oocmp->read(file=>'testout/t101_oo.jpg'), "read jpeg OO for comparison");

  $diff = sqrt(i_img_diff($imoo->{IMG},$oocmp->{IMG}))/150*150;
  print "# OO image difference $diff\n";
  ok($diff < 10000, "difference between original and jpeg within bounds");

  # write failure test
  open FH, "< testout/t101.jpg" or die "Cannot open testout/t101.jpg: $!";
  binmode FH;
  ok(!$imoo->write(fd=>fileno(FH), type=>'jpeg'), 'failure handling');
  close FH;
  print "# ",$imoo->errstr,"\n";

  # check that the i_format tag is set
  my @fmt = $imoo->tags(name=>'i_format');
  is($fmt[0], 'jpeg', 'i_format tag');

  { # check file limits are checked
    my $limit_file = "testout/t101.jpg";
    ok(Imager->set_file_limits(reset=>1, width=>149), "set width limit 149");
    my $im = Imager->new;
    ok(!$im->read(file=>$limit_file),
       "should fail read due to size limits");
    print "# ",$im->errstr,"\n";
    like($im->errstr, qr/image width/, "check message");
    
    ok(Imager->set_file_limits(reset=>1, height=>149), "set height limit 149");
    ok(!$im->read(file=>$limit_file),
       "should fail read due to size limits");
    print "# ",$im->errstr,"\n";
    like($im->errstr, qr/image height/, "check message");
    
    ok(Imager->set_file_limits(reset=>1, width=>150), "set width limit 150");
    ok($im->read(file=>$limit_file),
       "should succeed - just inside width limit");
    ok(Imager->set_file_limits(reset=>1, height=>150), "set height limit 150");
    ok($im->read(file=>$limit_file),
       "should succeed - just inside height limit");
    
    # 150 x 150 x 3 channel image uses 67500 bytes
    ok(Imager->set_file_limits(reset=>1, bytes=>67499),
       "set bytes limit 67499");
    ok(!$im->read(file=>$limit_file),
       "should fail - too many bytes");
    print "# ",$im->errstr,"\n";
    like($im->errstr, qr/storage size/, "check error message");
    ok(Imager->set_file_limits(reset=>1, bytes=>67500),
       "set bytes limit 67500");
    ok($im->read(file=>$limit_file),
       "should succeed - just inside bytes limit");
    Imager->set_file_limits(reset=>1);
  }

 SKIP:
  {
    # we don't test them all
    my %expected_tags =
      (
       exif_date_time_original => "2005:11:25 00:00:00",
       exif_flash => 0,
       exif_image_description => "Imager Development Notes",
       exif_make => "Canon",
       exif_model => "CanoScan LiDE 35",
       exif_resolution_unit => 2,
       exif_resolution_unit_name => "inches",
       exif_user_comment => "        Part of notes from reworking i_arc() and friends.",
       exif_white_balance => 0,
       exif_white_balance_name => "Auto white balance",
      );

    # exif tests
    Imager::i_exif_enabled()
	or skip("no exif support", scalar keys %expected_tags);

    my $im = Imager->new;
    $im->read(file=>"testimg/exiftest.jpg")
      or skip("Could not read test image:".$im->errstr, scalar keys %expected_tags);

    for my $key (keys %expected_tags) {
      is($expected_tags{$key}, $im->tags(name => $key),
	 "test value of exif tag $key");
    }
  }

  {
    # tests that the density values are set and read correctly
    # tests jpeg_comment too
    my @density_tests =
      (
       [ 't101cm100.jpg', 
	 { 
	  jpeg_density_unit => 2, 
	  i_xres => 254, 
	  i_yres => 254
	 },
	 { 
	  jpeg_density_unit => 2, 
	  i_xres => 254, 
	  i_yres => 254,
	  i_aspect_only => undef,
	 },
       ],
       [
	't101xonly.jpg',
	{
	 i_xres => 100,
	},
	{
	 i_xres => 100,
	 i_yres => 100,
	 jpeg_density_unit => 1,
	 i_aspect_only => undef,
	},
       ],
       [
	't101yonly.jpg',
	{
	 i_yres => 100,
	},
	{
	 i_xres => 100,
	 i_yres => 100,
	 jpeg_density_unit => 1,
	 i_aspect_only => undef,
	},
       ],
       [
	't101asponly.jpg',
	{
	 i_xres => 50,
	 i_yres => 100,
	 i_aspect_only => 1,
	},
	{
	 i_xres => 50,
	 i_yres => 100,
	 i_aspect_only => 1,
	 jpeg_density_unit => 0,
	},
       ],
       [
	't101com.jpg',
	{
	 jpeg_comment => 'test comment'
	},
       ],
      );

    print "# test density tags\n";
    # I don't care about the content
    my $base_im = Imager->new(xsize => 10, ysize => 10);
    for my $test (@density_tests) {
      my ($filename, $out_tags, $expect_tags) = @$test;
      $expect_tags ||= $out_tags;

      my $work = $base_im->copy;
      for my $key (keys %$out_tags) {
	$work->addtag(name => $key, value => $out_tags->{$key});
      }

      ok($work->write(file=>"testout/$filename", type=>'jpeg'),
	 "save $filename");
      
      my $check = Imager->new;
      ok($check->read(file=> "testout/$filename"),
	 "read $filename");

      my %tags;
      for my $key (keys %$expect_tags) {
	$tags{$key} = $check->tags(name=>$key);
      }
      is_deeply($expect_tags, \%tags, "check tags for $filename");
    }
  }

  { # Issue # 17981
    # the test image has a zero-length user_comment field
    # the code would originally attempt to convert '\0' to ' '
    # for the first 8 bytes, even if the string was less than 
    # 8 bytes long
    my $im = Imager->new;
    ok($im->read(file => 'testimg/209_yonge.jpg', type=>'jpeg'),
       "test read of image with invalid exif_user_comment");
    is($im->tags(name=>'exif_user_comment'), '',
       "check exif_user_comment set correctly");
  }

  { # test parseiptc handling no IPTC data correctly
    my $saw_warn;
    local $SIG{__WARN__} = 
      sub {
	++$saw_warn;
	print "# @_\n";
      };
    my $im = Imager->new;
    ok($im->read(file => 'testout/t101.jpg', type=>'jpeg'),
       "read jpeg with no IPTC data");
    ok(!defined $im->{IPTCRAW}, "no iptc data");
    my %iptc = $im->parseiptc;
    ok(!$saw_warn, "should be no warnings");
  }

  { # Issue # 18397
    # attempting to write a 4 channel image to a bufchain would
    # cause a seg fault.
    # it should fail still
    my $im = Imager->new(xsize => 10, ysize => 10, channels => 4);
    my $data;
    ok(!$im->write(data => \$data, type => 'jpeg'),
       "should fail to write but shouldn't crash");
    is($im->errstr, "only 1 or 3 channels images can be saved as JPEG",
       "check the error message");
  }
 SKIP:
  { # Issue # 18496
    # If a jpeg with EXIF data containing an (invalid) IFD entry with a 
    # type of zero is read then Imager crashes with a Floating point 
    # exception
    # testimg/zerojpeg.jpg was manually modified from exiftest.jpg to
    # reproduce the problem.
    Imager::i_exif_enabled()
	or skip("no exif support", 1);
    my $im = Imager->new;
    ok($im->read(file=>'testimg/zerotype.jpg'), "shouldn't crash");
  }

 SKIP:
  { # code coverage - make sure wiol_skip_input_data is called
    open BASEDATA, "< testimg/exiftest.jpg"
      or skip "can't open base data", 1;
    binmode BASEDATA;
    my $data = do { local $/; <BASEDATA> };
    close BASEDATA;
    
    substr($data, 3, 1) eq "\xE1"
      or skip "base data isn't as expected", 1;
    # inserting a lot of marker data here means we take the branch in 
    # wiol_skip_input_data that refills the buffer
    my $marker = "\xFF\xE9"; # APP9 marker
    $marker .= pack("n", 8192) . "x" x 8190;
    $marker x= 10; # make it take up a lot of space
    substr($data, 2, 0) = $marker;
    my $im = Imager->new;
    ok($im->read(data => $data), "read with a skip of data");
  }
  
 SKIP:
  { # code coverage - take the branch that provides a fake EOI
    open BASEDATA, "< testimg/exiftest.jpg"
      or skip "can't open base data", 1;
    binmode BASEDATA;
    my $data = do { local $/; <BASEDATA> };
    close BASEDATA;
    substr($data, -1000) = '';

    my $im = Imager->new;
    ok($im->read(data => $data), "read with image data truncated");
  }

  { # code coverage - make sure wiol_empty_output_buffer is called
    my $im = Imager->new(xsize => 1000, ysize => 1000);
    for my $x (0 .. 999) {
      $im->line(x1 => $x, y1 => 0, x2 => $x, y2 => 999,
                color => Imager::Color->new(rand 256, rand 256, rand 256));
    }
    my $data;
    ok($im->write(data => \$data, type=>'jpeg', jpegquality => 100), 
       "write big file to ensure wiol_empty_output_buffer is called");

    # code coverage - write failure path in wiol_empty_output_buffer
    ok(!$im->write(callback => sub { return },
                   type => 'jpeg', jpegquality => 100),
       "fail to write")
      and print "# ", $im->errstr, "\n";
  }

  { # code coverage - virtual image branch in i_writejpeg_wiol()
    my $im = $imoo->copy;
    my $immask = $im->masked;
    ok($immask, "made a virtual image (via masked)");
    ok($immask->virtual, "check it's virtual");
    my $mask_data;
    ok($immask->write(data => \$mask_data, type => 'jpeg'),
       "write masked version");
    my $base_data;
    ok($im->write(data => \$base_data, type=>'jpeg'),
       "write normal version");
    is($base_data, $mask_data, "check the data written matches");
  }

 SKIP:
  { # code coverage - IPTC data
    # this is dummy data
    my $iptc = "\x04\x04" .
      "\034\002x   My Caption"
        . "\034\002P   Tony Cook"
          . "\034\002i   Dummy Headline!"
            . "\034\002n   No Credit Given";
    
    my $app13 = "\xFF\xED" . pack("n", 2 + length $iptc) . $iptc;

    open BASEDATA, "< testimg/exiftest.jpg"
      or skip "can't open base data", 1;
    binmode BASEDATA;
    my $data = do { local $/; <BASEDATA> };
    close BASEDATA;
    substr($data, 2, 0) = $app13;

    my $im = Imager->new;
    ok($im->read(data => $data), "read with app13 data");
    my %iptc = $im->parseiptc;
    is($iptc{caption}, 'My Caption', 'check iptc caption');
    is($iptc{photogr}, 'Tony Cook', 'check iptc photogr');
    is($iptc{headln}, 'Dummy Headline!', 'check iptc headln');
    is($iptc{credit}, 'No Credit Given', 'check iptc credit');
  }

  { # handling of CMYK jpeg
    # http://rt.cpan.org/Ticket/Display.html?id=20416
    my $im = Imager->new;
    ok($im->read(file => 'testimg/scmyk.jpg'), 'read a CMYK jpeg');
    is($im->getchannels, 3, "check channel count");
    my $col = $im->getpixel(x => 0, 'y' => 0);
    ok($col, "got the 'black' pixel");
    # this is jpeg, so we can't compare colors exactly
    # older versions returned this pixel at a light color, but
    # it's black in the image
    my ($r, $g, $b) = $col->rgba;
    cmp_ok($r, '<', 10, 'black - red low');
    cmp_ok($g, '<', 10, 'black - green low');
    cmp_ok($b, '<', 10, 'black - blue low');
    $col = $im->getpixel(x => 15, 'y' => 0);
    ok($col, "got the dark blue");
    ($r, $g, $b) = $col->rgba;
    cmp_ok($r, '<', 10, 'dark blue - red low');
    cmp_ok($g, '<', 10, 'dark blue - green low');
    cmp_ok($b, '>', 110, 'dark blue - blue middle (bottom)');
    cmp_ok($b, '<', 130, 'dark blue - blue middle (top)');
    $col = $im->getpixel(x => 0, 'y' => 15);
    ok($col, "got the red");
    ($r, $g, $b) = $col->rgba;
    cmp_ok($r, '>', 245, 'red - red high');
    cmp_ok($g, '<', 10, 'red - green low');
    cmp_ok($b, '<', 10, 'red - blue low');
  }
}

