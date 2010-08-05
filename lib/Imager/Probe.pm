package Imager::Probe;
use strict;
use File::Spec;
use Config;

sub probe {
  my ($class, $req) = @_;

  my $result;
  if ($req->{code}) {
    $result = _probe_code($req->{code});
  }
  if (!$result && $req->{pkg}) {
    $result = _probe_pkg(@{$req->{pkg}});
  }
  if (!$result) {
    my $libcheck = $req->{libcheck};
    if (!$libcheck && $req->{libname}) {
      # synthesize a libcheck
      my $lext=$Config{'so'};   # Get extensions of libraries
      my $aext=$Config{'_a'};
      my $libname = $req->{libname};
      $libcheck = sub {
	-e File::Spec->catfile($_[0], "$libname$aext")
	  || -e File::Spec->catfile($_[0], "$libname.$lext")
      };
    }
    if ($req->{inccheck} && $libcheck) {
      $result = _probe_check($req->{inccheck}, $req->{libcheck});
    }
  }
  $result or return;

  if ($req->{testcode}) {
    $result = _probe_test($result, $req->{testcode});
  }

  $result or return;

  return $result;
}

sub _probe_code {
  my ($code) = @_;

  my @probes = ref $code eq "ARRAY" ? @$code : $code;

  my $result;
  for my $probe (@probes) {
    $result = $probe->()
      and return $result;
  }

  return;
}

sub is_exe {
  my ($name) = @_;

  my @exe_suffix = $Config{_exe};
  if ($^O eq 'MSWin32') {
    push @exe_suffix, qw/.bat .cmd/;
  }

  for my $dir (File::Spec->path) {
    for my $suffix (@exe_suffix) {
      -x File::Spec->catfile($dir, "$name$suffix")
	and return 1;
    }
  }

  return;
}

sub _probe_pkg {
  my (@pkgs) = @_;

  $DB::single = 1;
  is_exe('pkg-config') or return;
  my $redir = $^O eq 'MSWin32' ? '' : '2>/dev/null';

  for my $pkg (@pkgs) {
    if (!system("pkg-config $pkg --exists $redir")) {
      print STDERR "Found $pkg\n";
      # if we find it, but the following fail, then pkg-config is too
      # broken to be useful
      my $cflags = `pkg-config $pkg --cflags`
	and !$? or return;

      my $lflags = `pkg-config $pkg --libs`
	and !$? or return;

      chomp $cflags;
      chomp $lflags;
      return
	{
	 INC => $cflags,
	 LIBS => $lflags,
	};

    }
  }

  return;
}

1;

__END__

=head1 NAME

Imager::Probe - hot needle of enquiry for libraries

=head1 SYNOPSIS

  require Imager::Probe;

  my %probe = 
    (
     # pkg-config lookup
     pkg => [ qw/name1 name2 name3/ ],
     
    );
  my $result = Imager::Probe->probe(\%probe)
    or print "Foo library not found: ",Imager::Probe->error;

=head1 DESCRIPTION

Does the probes that were hidden in Imager's Makefile.PL, pulled out
so the file format libraries can be externalized.

The return value is either nothing if the probe fails, or a hash
containing:

=over

=item *

INC - -I and other C options

=item *

LIBS - -L, -l and other link-time options

=back

The possible values for the hash supplied to the probe() method are:

=over

=item *

cfg - an array of pkg-config names to probe for.  If the pkg-config
checks pass, inccheck and libcheck aren't used.

=item *

inccheck - a code reference that checks if the supplied include
directory contains the required header files.

=item *

libcheck - a code reference that checks if the supplied library
directory contains the required library files.  Note: the Makefile.PL
version of this was supplied all of the library filenames instead.

=item *

libfiles - if the libraries are found via inccheck/libcheck, these are
the -l options to supply during the link phase.

=item *

code - a code reference to perform custom checks.  Returns the probe
result directly.  Can also be an array ref of functions to call.

=back

=cut
