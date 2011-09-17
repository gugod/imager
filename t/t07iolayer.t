#!perl -w
use strict;
use Test::More tests => 159;
# for SEEK_SET etc, Fcntl doesn't provide these in 5.005_03
use IO::Seekable;

BEGIN { use_ok(Imager => ':all') };

-d "testout" or mkdir "testout";

$| = 1;

Imager->open_log(log => "testout/t07iolayer.log");

undef($/);
# start by testing io buffer

my $data="P2\n2 2\n255\n 255 0\n0 255\n";
my $IO = Imager::io_new_buffer($data);
my $im = Imager::i_readpnm_wiol($IO, -1);

ok($im, "read from data io");

open(FH, ">testout/t07.ppm") or die $!;
binmode(FH);
my $fd = fileno(FH);
my $IO2 = Imager::io_new_fd( $fd );
Imager::i_writeppm_wiol($im, $IO2);
close(FH);
undef($im);

open(FH, "<testimg/penguin-base.ppm");
binmode(FH);
$data = <FH>;
close(FH);
my $IO3 = Imager::io_new_buffer($data);
#undef($data);
$im = Imager::i_readpnm_wiol($IO3, -1);

ok($im, "read from buffer, for compare");
undef $IO3;

open(FH, "<testimg/penguin-base.ppm") or die $!;
binmode(FH);
$fd = fileno(FH);
my $IO4 = Imager::io_new_fd( $fd );
my $im2 = Imager::i_readpnm_wiol($IO4, -1);
close(FH);
undef($IO4);

ok($im2, "read from file, for compare");

is(i_img_diff($im, $im2), 0, "compare images");
undef($im2);

my $IO5 = Imager::io_new_bufchain();
Imager::i_writeppm_wiol($im, $IO5);
my $data2 = Imager::io_slurp($IO5);
undef($IO5);

ok($data2, "check we got data from bufchain");

my $IO6 = Imager::io_new_buffer($data2);
my $im3 = Imager::i_readpnm_wiol($IO6, -1);

is(Imager::i_img_diff($im, $im3), 0, "read from buffer");

my $work = $data;
my $pos = 0;
sub io_reader {
  my ($size, $maxread) = @_;
  my $out = substr($work, $pos, $maxread);
  $pos += length $out;
  $out;
}
sub io_reader2 {
  my ($size, $maxread) = @_;
  my $out = substr($work, $pos, $maxread);
  $pos += length $out;
  $out;
}
my $IO7 = Imager::io_new_cb(undef, \&io_reader, undef, undef);
ok($IO7, "making readcb object");
my $im4 = Imager::i_readpnm_wiol($IO7, -1);
ok($im4, "read from cb");
ok(Imager::i_img_diff($im, $im4) == 0, "read from cb image match");

$pos = 0;
$IO7 = Imager::io_new_cb(undef, \&io_reader2, undef, undef);
ok($IO7, "making short readcb object");
my $im5 = Imager::i_readpnm_wiol($IO7, -1);
ok($im4, "read from cb2");
is(Imager::i_img_diff($im, $im5), 0, "read from cb2 image match");

sub io_writer {
  my ($what) = @_;
  substr($work, $pos, $pos+length $what) = $what;
  $pos += length $what;

  1;
}

my $did_close;
sub io_close {
  ++$did_close;
}

my $IO8 = Imager::io_new_cb(\&io_writer, undef, undef, \&io_close);
ok($IO8, "making writecb object");
$pos = 0;
$work = '';
ok(Imager::i_writeppm_wiol($im, $IO8), "write to cb");
# I originally compared this to $data, but that doesn't include the
# Imager header
is($work, $data2, "write image match");
ok($did_close, "did close");

# with a short buffer, no closer
my $IO9 = Imager::io_new_cb(\&io_writer, undef, undef, undef, 1);
ok($IO9, "making short writecb object");
$pos = 0;
$work = '';
ok(Imager::i_writeppm_wiol($im, $IO9), "write to short cb");
is($work, $data2, "short write image match");

{
  my $buf_data = "Test data";
  my $io9 = Imager::io_new_buffer($buf_data);
  is(ref $io9, "Imager::IO", "check class");
  my $work;
  is($io9->raw_read($work, 4), 4, "read 4 from buffer object");
  is($work, "Test", "check data read");
  is($io9->raw_read($work, 5), 5, "read the rest");
  is($work, " data", "check data read");
  is($io9->raw_seek(5, SEEK_SET), 5, "seek");
  is($io9->raw_read($work, 5), 4, "short read");
  is($work, "data", "check data read");
  is($io9->raw_seek(-1, SEEK_CUR), 8, "seek relative");
  is($io9->raw_seek(-5, SEEK_END), 4, "seek relative to end");
  is($io9->raw_seek(-10, SEEK_CUR), -1, "seek failure");
  undef $io9;
}
{
  my $io = Imager::io_new_bufchain();
  is(ref $io, "Imager::IO", "check class");
  is($io->raw_write("testdata"), 8, "check write");
  is($io->raw_seek(-8, SEEK_CUR), 0, "seek relative");
  my $work;
  is($io->raw_read($work, 8), 8, "check read");
  is($work, "testdata", "check data read");
  is($io->raw_seek(-3, SEEK_END), 5, "seek end relative");
  is($io->raw_read($work, 5), 3, "short read");
  is($work, "ata", "check read data");
  is($io->raw_seek(4, SEEK_SET), 4, "absolute seek to write some");
  is($io->raw_write("testdata"), 8, "write");
  is($io->raw_seek(0, SEEK_CUR), 12, "check size");
  $io->raw_close();
  
  # grab the data
  my $data = Imager::io_slurp($io);
  is($data, "testtestdata", "check we have the right data");
}

{ # callback failure checks
  my $fail_io = Imager::io_new_cb(\&fail_write, \&fail_read, \&fail_seek, undef, 1);
  # scalar context
  my $buffer;
  my $read_result = $fail_io->raw_read($buffer, 10);
  is($read_result, undef, "read failure undef in scalar context");
  my @read_result = $fail_io->raw_read($buffer, 10);
  is(@read_result, 0, "empty list in list context");
  $read_result = $fail_io->raw_read2(10);
  is($read_result, undef, "raw_read2 failure (scalar)");
  @read_result = $fail_io->raw_read2(10);
  is(@read_result, 0, "raw_read2 failure (list)");

  my $write_result = $fail_io->raw_write("test");
  is($write_result, -1, "failed write");

  my $seek_result = $fail_io->raw_seek(-1, SEEK_SET);
  is($seek_result, -1, "failed seek");
}

{ # callback success checks
  my $good_io = Imager::io_new_cb(\&good_write, \&good_read, \&good_seek, undef, 1);
  # scalar context
  my $buffer;
  my $read_result = $good_io->raw_read($buffer, 10);
  is($read_result, 8, "read success (scalar)");
  is($buffer, "testdata", "check data");
  my @read_result = $good_io->raw_read($buffer, 10);
  is_deeply(\@read_result, [ 8 ], "read success (list)");
  is($buffer, "testdata", "check data");
  $read_result = $good_io->raw_read2(10);
  is($read_result, "testdata", "read2 success (scalar)");
  @read_result = $good_io->raw_read2(10);
  is_deeply(\@read_result, [ "testdata" ], "read2 success (list)");
}

{ # end of file
  my $eof_io = Imager::io_new_cb(undef, \&eof_read, undef, undef, 1);
  my $buffer;
  my $read_result = $eof_io->raw_read($buffer, 10);
  is($read_result, 0, "read eof (scalar)");
  is($buffer, '', "check data");
  my @read_result = $eof_io->raw_read($buffer, 10);
  is_deeply(\@read_result, [ 0 ], "read eof (list)");
  is($buffer, '', "check data");
}

{ # no callbacks
  my $none_io = Imager::io_new_cb(undef, undef, undef, undef, 0);
  is($none_io->raw_write("test"), -1, "write with no writecb should fail");
  my $buffer;
  is($none_io->raw_read($buffer, 10), undef, "read with no readcb should fail");
  is($none_io->raw_seek(0, SEEK_SET), -1, "seek with no seekcb should fail");
}

SKIP:
{ # make sure we croak when trying to write a string with characters over 0xff
  # the write callback shouldn't get called
  skip("no native UTF8 support in this version of perl", 2)
    unless $] >= 5.006;
  my $io = Imager::io_new_cb(\&good_write, undef, undef, 1);
  my $data = chr(0x100);
  is(ord $data, 0x100, "make sure we got what we expected");
  my $result = 
    eval {
      $io->raw_write($data);
    };
  ok($@, "should have croaked")
    and print "# $@\n";
}

{ # 0.52 left some debug code in a path that wasn't tested, make sure
  # that path is tested
  # http://rt.cpan.org/Ticket/Display.html?id=20705
  my $io = Imager::io_new_cb
    (
     sub { 
       print "# write $_[0]\n";
       1 
     }, 
     sub { 
       print "# read $_[0], $_[1]\n";
       "x" x $_[1]
     }, 
     sub { print "# seek\n"; 0 }, 
     sub { print "# close\n"; 1 });
  my $buffer;
  is($io->raw_read($buffer, 10), 10, "read 10");
  is($buffer, "xxxxxxxxxx", "read value");
  ok($io->raw_write("foo"), "write");
  is($io->raw_close, 0, "close");
}

SKIP:
{ # fd_seek write failure
  -c "/dev/full"
    or skip("No /dev/full", 3);
  open my $fh, "> /dev/full"
    or skip("Can't open /dev/full: $!", 3);
  my $io = Imager::io_new_fd(fileno($fh));
  ok($io, "make fd io for /dev/full");
  Imager::i_clear_error();
  is($io->raw_write("test"), -1, "fail to write");
  my $msg = Imager->_error_as_msg;
  like($msg, qr/^write\(\) failure: /, "check error message");
  print "# $msg\n";

  # /dev/full succeeds on seek on Linux

  undef $io;
}

SKIP:
{ # fd_seek seek failure
  my $seekfail = "testout/t07seekfail.dat";
  open my $fh, "> $seekfail"
    or skip("Can't open $seekfail: $!", 3);
  my $io = Imager::io_new_fd(fileno($fh));
  ok($io, "make fd io for $seekfail");

  Imager::i_clear_error();
  is($io->raw_seek(-1, SEEK_SET), -1, "shouldn't be able to seek to -1");
  my $msg = Imager->_error_as_msg;
  like($msg, qr/^lseek\(\) failure: /, "check error message");
  print "# $msg\n";

  undef $io;
  close $fh;
  unlink $seekfail;
}

SKIP:
{ # fd_seek read failure
  open my $fh, "> testout/t07writeonly.txt"
    or skip("Can't open testout/t07writeonly.txt: $!", 3);
  my $io = Imager::io_new_fd(fileno($fh));
  ok($io, "make fd io for write-only");

  Imager::i_clear_error();
  my $buf;
  is($io->raw_read($buf, 10), undef,
     "file open for write shouldn't be readable");
  my $msg = Imager->_error_as_msg;
  like($msg, qr/^read\(\) failure: /, "check error message");
  print "# $msg\n";

  undef $io;
}

SKIP:
{ # fd_seek eof
  open my $fh, "> testout/t07readeof.txt"
    or skip("Can't open testout/t07readeof.txt: $!", 5);
  binmode $fh;
  print $fh "test";
  close $fh;
  open my $fhr, "< testout/t07readeof.txt",
    or skip("Can't open testout/t07readeof.txt: $!", 5);
  my $io = Imager::io_new_fd(fileno($fhr));
  ok($io, "make fd io for read eof");

  Imager::i_clear_error();
  my $buf;
  is($io->raw_read($buf, 10), 4,
     "10 byte read on 4 byte file should return 4");
  my $msg = Imager->_error_as_msg;
  is($msg, "", "should be no error message")
    or print STDERR "# read(4) message is: $msg\n";

  Imager::i_clear_error();
  $buf = '';
  is($io->raw_read($buf, 10), 0,
     "10 byte read at end of 4 byte file should return 0 (eof)");

  $msg = Imager->_error_as_msg;
  is($msg, "", "should be no error message")
    or print STDERR "# read(4), eof message is: $msg\n";

  undef $io;
}

{ # buffered I/O
  my $data="P2\n2 2\n255\n 255 0\n0 255\n";
  my $io = Imager::io_new_buffer($data);

  my $c = $io->getc();

  is($c, ord "P", "getc");
  my $peekc = $io->peekc();

  is($peekc, ord "2", "peekc");

  my $peekn = $io->peekn(2);
  is($peekn, "2\n", "peekn");

  $c = $io->getc();
  is($c, ord "2", "getc after peekc/peekn");

  is($io->seek(0, SEEK_SET), "0", "seek");
  is($io->getc, ord "P", "check we got back to the start");
}

{ # test closecb result is propagated
  my $success_cb = sub { 1 };
  my $failure_cb = sub { 0 };

  {
    my $io = Imager::io_new_cb(undef, $success_cb, undef, $success_cb);
    is($io->close(), 0, "test successful close");
  }
  {
    my $io = Imager::io_new_cb(undef, $success_cb, undef, $failure_cb);
    is($io->close(), -1, "test failed close");
  }
}

{ # buffered coverage/function tests
  # some data to play with
  my $base = pack "C*", map rand(26) + ord("a"), 0 .. 20_001;

  { # initial i_io_read(), buffered
    my $pos = 0;
    my $ops = "";
    my $work = $base;
    my $read = sub {
      my ($size) = @_;

      my $req_size = $size;

      if ($pos + $size > length $work) {
	$size = length($work) - $pos;
      }

      my $result = substr($work, $pos, $size);
      $pos += $size;
      $ops .= "R$req_size>$size;";

      print "# read $req_size>$size\n";

      return $result;
    };
    my $write = sub {
      my ($data) = @_;

      substr($work, $pos, length($data), $data);

      return 1;
    };
    {
      my $io = Imager::io_new_cb(undef, $read, undef, undef);
      my $buf;
      is($io->read($buf, 1000), 1000, "read initial 1000");
      is($buf, substr($base, 0, 1000), "check data read");
      is($ops, "R8192>8192;", "check read op happened to buffer size");

      undef $buf;
      is($io->read($buf, 1001), 1001, "read another 1001");
      is($buf, substr($base, 1000, 1001), "check data read");
      is($ops, "R8192>8192;", "should be no further reads");

      undef $buf;
      is($io->read($buf, 40_000), length($base) - 2001,
	 "read the rest in one chunk");
      is($buf, substr($base, 2001), "check the data read");
      my $buffer_left = 8192 - 2001;
      my $after_buffer = length($base) - 8192;
      is($ops, "R8192>8192;R".(40_000 - $buffer_left).">$after_buffer;R21999>0;",
	 "check we tried to read the remainder");
    }
    {
      # read after write errors
      my $io = Imager::io_new_cb($write, $read, undef, undef);
      is($io->write("test"), 4, "write 4 bytes, io in write mode");
      is($io->read2(10), undef, "read should fail");
      is($io->peekn(10), undef, "peekn should fail");
      is($io->getc(), -1, "getc should fail");
      is($io->peekc(), -1, "peekc should fail");
    }
  }

  {
    my $io = Imager::io_new_buffer($base);
    print "# buffer fill check\n";
    ok($io, "make memory io");
    my $buf;
    is($io->read($buf, 4096), 4096, "read 4k");
    is($buf, substr($base, 0, 4096), "check data is correct");

    # peek a bit
    undef $buf;
    is($io->peekn(5120), substr($base, 4096, 5120),
       "peekn() 5120, which should exceed the buffer, and only read the left overs");
  }

  { # initial peekn
    my $io = Imager::io_new_buffer($base);
    is($io->peekn(10), substr($base, 0, 10),
       "make sure initial peekn() is sane");
    is($io->read2(10), substr($base, 0, 10),
       "and that reading 10 gets the expected data");
  }

  { # oversize peekn
    my $io = Imager::io_new_buffer($base);
    is($io->peekn(10_000), substr($base, 0, 8192),
       "peekn() larger than buffer should return buffer-size bytes");
  }

  { # small peekn then large peekn with a small I/O back end
    # this might happen when reading from a socket
    my $work = $base;
    my $pos = 0;
    my $ops = '';
    my $reader = sub {
      my ($size) = @_;

      my $req_size = $size;
      # do small reads, to trigger a possible bug
      if ($size > 10) {
	$size = 10;
      }

      if ($pos + $size > length $work) {
	$size = length($work) - $pos;
      }

      my $result = substr($work, $pos, $size);
      $pos += $size;
      $ops .= "R$req_size>$size;";

      print "# read $req_size>$size\n";

      return $result;
    };
    my $io = Imager::io_new_cb(undef, $reader, undef, undef);
    ok($io, "small reader io");
    is($io->peekn(25), substr($base, 0, 25), "peek 25");
    is($ops, "R8192>10;R8182>10;R8172>10;",
       "check we got the raw calls expected");
    is($io->peekn(65), substr($base, 0, 65), "peek 65");
    is($ops, "R8192>10;R8182>10;R8172>10;R8162>10;R8152>10;R8142>10;R8132>10;",
       "check we got the raw calls expected");
  }
  { # peekn followed by errors
    my $read = 0;
    my $base = "abcdef";
    my $pos = 0;
    my $reader = sub {
      my $size = shift;
      my $req_size = $size;
      if ($pos + $size > length $base) {
	$size = length($base) - $pos;
      }
      # error instead of eof
      if ($size == 0) {
	print "# read $req_size>error\n";
	return;
      }
      my $result = substr($base, $pos, $size);
      $pos += $size;

      print "# read $req_size>$size\n";

      return $result;
    };
    my $io = Imager::io_new_cb(undef, $reader, undef, undef);
    is($io->peekn(5), "abcde", "peekn until just before error");
    is($io->peekn(6), "abcdef", "peekn until error");
    is($io->peekn(7), "abcdef", "peekn past error");
    ok(!$io->error, "should be no error indicator, since data buffered");
    ok(!$io->eof, "should be no eof indicator, since data buffered");

    # consume it
    is($io->read2(6), "abcdef", "consume the buffer");
    is($io->peekn(10), undef, "should get an error indicator");
    ok($io->error, "should be an error state");
    ok(!$io->eof, "but not eof");
  }
  { # getc through a whole file (buffered)
    my $io = Imager::io_new_buffer($base);
    my $out = '';
    while ((my $c = $io->getc()) != -1) {
      $out .= chr($c);
    }
    is($out, $base, "getc should return the file byte by byte (buffered)");
    is($io->getc, -1, "another getc after eof should fail too");
    ok($io->eof, "should be marked eof");
    ok(!$io->error, "shouldn't be marked in error");
  }
  { # getc through a whole file (unbuffered)
    my $io = Imager::io_new_buffer($base);
    $io->set_buffered(0);
    my $out = '';
    while ((my $c = $io->getc()) != -1) {
      $out .= chr($c);
    }
    is($out, $base, "getc should return the file byte by byte (unbuffered)");
    is($io->getc, -1, "another getc after eof should fail too");
    ok($io->eof, "should be marked eof");
    ok(!$io->error, "shouldn't be marked in error");
  }
  { # buffered getc with an error
    my $io = Imager::io_new_cb(undef, sub { return; }, undef, undef);
    is($io->getc, -1, "buffered getc error");
    ok($io->error, "io marked in error");
    ok(!$io->eof, "but not eof");
  }
  { # unbuffered getc with an error
    my $io = Imager::io_new_cb(undef, sub { return; }, undef, undef);
    $io->set_buffered(0);
    is($io->getc, -1, "unbuffered getc error");
    ok($io->error, "io marked in error");
    ok(!$io->eof, "but not eof");
  }
  { # initial peekc - buffered
    my $io = Imager::io_new_buffer($base);
    my $c = $io->peekc;
    is($c, ord($base), "buffered peekc matches");
    is($io->peekc, $c, "duplicate peekc matchess");
  }
  { # initial peekc - unbuffered
    my $io = Imager::io_new_buffer($base);
    $io->set_buffered(0);
    my $c = $io->peekc;
    is($c, ord($base), "unbuffered peekc matches");
    is($io->peekc, $c, "duplicate peekc matchess");
  }
  { # initial peekc eof - buffered
    my $io = Imager::io_new_cb(undef, sub { "" }, undef, undef);
    my $c = $io->peekc;
    is($c, -1, "buffered eof peekc is -1");
    is($io->peekc, $c, "duplicate matches");
    ok($io->eof, "io marked eof");
    ok(!$io->error, "but not error");
  }
  { # initial peekc eof - unbuffered
    my $io = Imager::io_new_cb(undef, sub { "" }, undef, undef);
    $io->set_buffered(0);
    my $c = $io->peekc;
    is($c, -1, "buffered eof peekc is -1");
    is($io->peekc, $c, "duplicate matches");
    ok($io->eof, "io marked eof");
    ok(!$io->error, "but not error");
  }
  { # initial peekc error - buffered
    my $io = Imager::io_new_cb(undef, sub { return; }, undef, undef);
    my $c = $io->peekc;
    is($c, -1, "buffered error peekc is -1");
    is($io->peekc, $c, "duplicate matches");
    ok($io->error, "io marked error");
    ok(!$io->eof, "but not eof");
  }
  { # initial peekc error - unbuffered
    my $io = Imager::io_new_cb(undef, sub { return; }, undef, undef);
    $io->set_buffered(0);
    my $c = $io->peekc;
    is($c, -1, "unbuffered error peekc is -1");
    is($io->peekc, $c, "duplicate matches");
    ok($io->error, "io marked error");
    ok(!$io->eof, "but not eof");
  }
}

Imager->close_log;

unless ($ENV{IMAGER_KEEP_FILES}) {
  unlink "testout/t07.ppm", "testout/t07iolayer.log";
}

sub eof_read {
  my ($max_len) = @_;

  return '';
}

sub good_read {
  my ($max_len) = @_;

  my $data = "testdata";
  length $data <= $max_len or substr($data, $max_len) = '';

  print "# good_read ($max_len) => $data\n";

  return $data;
}

sub fail_write {
  return;
}

sub fail_read {
  return;
}

sub fail_seek {
  return -1;
}
