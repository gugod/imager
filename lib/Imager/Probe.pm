package Imager::Probe;
use strict;
use File::Spec;
use Config;

sub probe {
  my ($class, $req) = @_;

  my $name = $req->{name};
  my $result;
  if ($req->{code}) {
    $result = _probe_code($req);
  }
  if (!$result && $req->{pkg}) {
    $result = _probe_pkg($req);
  }
  if (!$result && $req->{inccheck} && ($req->{libcheck} || $req->{libbase})) {
    $result = _probe_check($req);
  }
  $result or return;

  if ($req->{testcode}) {
    $result = _probe_test($req, $result);
  }

  $result or return;

  return $result;
}

sub _probe_code {
  my ($req) = @_;

  my $code = $req->{code};
  my @probes = ref $code eq "ARRAY" ? @$code : $code;

  my $result;
  for my $probe (@probes) {
    $result = $probe->($req)
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
  my ($req) = @_;

  $DB::single = 1;
  is_exe('pkg-config') or return;
  my $redir = $^O eq 'MSWin32' ? '' : '2>/dev/null';

  my @pkgs = @{$req->{pkg}};
  for my $pkg (@pkgs) {
    if (!system("pkg-config $pkg --exists $redir")) {
      # if we find it, but the following fail, then pkg-config is too
      # broken to be useful
      my $cflags = `pkg-config $pkg --cflags`
	and !$? or return;

      my $lflags = `pkg-config $pkg --libs`
	and !$? or return;

      chomp $cflags;
      chomp $lflags;
      print "$req->{name}: Found via pkg-config $pkg\n";
      return
	{
	 INC => $cflags,
	 LIBS => $lflags,
	};
    }
  }

  print "$req->{name}: Not found via pkg-config\n";

  return;
}

sub _probe_check {
  my ($req) = @_;

  my $libcheck = $req->{libcheck};
  my $libbase = $req->{libbase};
  if (!$libcheck && $req->{libbase}) {
    # synthesize a libcheck
    my $lext=$Config{'so'};   # Get extensions of libraries
    my $aext=$Config{'_a'};
    $libcheck = sub {
      -e File::Spec->catfile($_[0], "lib$libbase$aext")
	|| -e File::Spec->catfile($_[0], "lib$libbase.$lext")
      };
  }

  my $found_libpath;
  my @lib_search = _lib_paths($req);
  for my $path (@lib_search) {
    if ($libcheck->($path)) {
      $found_libpath = $path;
      last;
    }
  }

  my $found_incpath;
  my $inccheck = $req->{inccheck};
  my @inc_search = _inc_paths($req);
  for my $path (@inc_search) {
    if ($inccheck->($path)) {
      $found_incpath = $path;
      last;
    }
  }

  print "$req->{name}: includes ", $found_incpath ? "" : "not ",
    "found - libraries ", $found_libpath ? "" : "not ", "found\n";

  $found_libpath && $found_incpath
    or return;

  my @libs = "-L$found_libpath";
  if ($req->{libopts}) {
    push @libs, $req->{libopts};
  }
  elsif ($libbase) {
    push @libs, "-l$libbase";
  }
  else {
    die "$req->{name}: inccheck but no libbase or libopts";
  }

  return
    {
     INC => "-I$found_incpath",
     LIBS => "@libs",
    };
}

sub _lib_paths {
  my ($req) = @_;

  return _paths
    (
     $ENV{IM_LIBPATH},
     $req->{libpath},
     (
      map { split ' ' }
      grep $_,
      @Config{qw/locincpath incpath libspath/}
     ),
     $^O eq "MSWin32" ? $ENV{LIB} : "",
     $^O eq "cygwin" ? "/usr/lib/w32api" : "",
    );
}

sub _inc_paths {
  my ($req) = @_;

  return _paths
    (
     $ENV{IM_INCPATH},
     $req->{incpath},
     $^O eq "MSWin32" ? $ENV{INCLUDE} : "",
     $^O eq "cygwin" ? "/usr/include/w32api" : "",
     "/usr/include",
     "/usr/local/include",
    );
}

sub _paths {
  my (@in) = @_;

  my @out;

  for my $path (@in) {
    $path or next;

    push @out, grep -d $_, split /\Q$Config{path_sep}/, $path;
  }

  return @out;
}

1;

__END__

=head1 NAME

Imager::Probe - hot needle of inquiry for libraries

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

Does the probes that were hidden in Imager's F<Makefile.PL>, pulled
out so the file format libraries can be externalized.

The return value is either nothing if the probe fails, or a hash
containing:

=over

=item *

C<INC> - C<-I> and other C options

=item *

C<LIBS> - C<-L>, C<-l> and other link-time options

=back

The possible values for the hash supplied to the probe() method are:

=over

=item *

C<pkg> - an array of F<pkg-config> names to probe for.  If the
F<pkg-config> checks pass, C<inccheck> and C<libcheck> aren't used.

=item *

C<inccheck> - a code reference that checks if the supplied include
directory contains the required header files.

=item *

C<libcheck> - a code reference that checks if the supplied library
directory contains the required library files.  Note: the
F<Makefile.PL> version of this was supplied all of the library file
names instead.

=item *

C<libbase> - if C<inccheck> is supplied, but C<libcheck> isn't, then a
C<libcheck> that checks for C<lib>I<libbase>I<$Config{_a}> and
C<lib>I<libbase>.I<$Config{so}> is created.  If C<libopts> isn't
supplied then that can be synthesized as C<-l>C<<I<libbase>>>.

=item *

C<libopts> - if the libraries are found via C<inccheck>/C<libcheck>,
these are the C<-l> options to supply during the link phase.

=item *

C<code> - a code reference to perform custom checks.  Returns the
probe result directly.  Can also be an array ref of functions to call.

=back

=cut
