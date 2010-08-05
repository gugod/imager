#!perl -w
use strict;
use ExtUtils::MakeMaker qw(WriteMakefile WriteEmptyMakefile);

our $BUILDING_IMAGER;

my %opts = 
  (
   NAME => 'Imager::File::PNG',
   VERSION_FROM => 'PNG.pm',
   OBJECT => 'PNG.o impng.o',
  );

my @inc;
if ($BUILDING_IMAGER) {
  print "Building PNG under Imager\n";
  push @inc, "-I..";
  push @INC, "../lib";
}
else {
  require Imager::ExtUtils;
  push @inc, Imager::ExtUtils->includes;
  $opts{TYPEMAPS} = [ Imager::ExtUtils->typemap ],
}

require Imager::Probe;

my %probe =
  (
   pkg => [ qw/libpng14 libpng12 libpng10 libpng/ ],
   inccheck => sub { -e File::Spec->catfile($_[0], "png.h") },
   libbase => "libpng",
  );
$DB::single = 1;
my $probe_res = Imager::Probe->probe(\%probe);
unless ($probe_res) {
  if ($BUILDING_IMAGER) {
    WriteEmptyMakefile();
  }
  else {
    # fail in good way
    die "OS unsupported: PNG libraries or headers not found\n";
  }
}

push @inc, $probe_res->{INC};
$opts{LIBS} = $probe_res->{LIBS};

$opts{INC} = "@inc";

my $MM_ver = eval $ExtUtils::MakeMaker::VERSION;
if ($MM_ver > 6.06) {
  $opts{AUTHOR} = 'Tony Cook <tony@imager.perl.org>';
  $opts{ABSTRACT} = 'PNG Image file support';
}

WriteMakefile(%opts);


