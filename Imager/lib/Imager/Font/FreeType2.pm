package Imager::Font::FreeType2;
use strict;
use Imager::Color;
use vars qw(@ISA);
@ISA = qw(Imager::Font);
sub new {
  my $class = shift;
  my %hsh=(color=>Imager::Color->new(255,0,0,0),
	   size=>15,
	   @_);

  unless ($hsh{file}) {
    $Imager::ERRSTR = "No font file specified";
    return;
  }
  unless (-e $hsh{file}) {
    $Imager::ERRSTR = "Font file $hsh{file} not found";
    return;
  }
  unless ($Imager::formats{ft2}) {
    $Imager::ERRSTR = "Freetype2 not supported in this build";
    return;
  }
  my $id = i_ft2_new($hsh{file}, $hsh{index} || 0);
  unless ($id) { # the low-level code may miss some error handling
    $Imager::ERRSTR = Imager::_error_as_msg();
    return;
  }
  return bless {
		id    => $id,
		aa    => $hsh{aa} || 0,
		file  => $hsh{file},
		type  => 't1',
		size  => $hsh{size},
		color => $hsh{color},
	       }, $class;
}

sub _draw {
  my $self = shift;
  my %input = @_;
  if (exists $input{channel}) {
    i_ft2_cp($self->{id}, $input{image}{IMG}, $input{x}, $input{'y'},
             $input{channel}, $input{size}, $input{sizew} || 0,
             $input{string}, , $input{align}, $input{aa});
  } else {
    i_ft2_text($self->{id}, $input{image}{IMG}, 
               $input{x}, $input{'y'}, 
               $input{color}, $input{size}, $input{sizew} || 0,
               $input{string}, $input{align}, $input{aa});
  }

  return $self;
}

sub _bounding_box {
  my $self = shift;
  my %input = @_;
  return i_t1_bbox($self->{id}, $input{size}, $input{sizew}, $input{string});
}

sub dpi {
  my $self = shift;
  my @old = i_ft2_getdpi($self->{id});
  if (@_) {
    my %hsh = @_;
    my $result;
    unless ($hsh{xdpi} && $hsh{ydpi}) {
      if ($hsh{dpi}) {
        $hsh{xdpi} = $hsh{ydpi} = $hsh{dpi};
      }
      else {
        $Imager::ERRSTR = "dpi method requires xdpi and ydpi or just dpi";
        return;
      }
      i_ft2_setdpi($self->{id}, $hsh{xdpi}, $hsh{ydpi}) or return;
    }
  }
  
  return @old;
}

sub _transform {
  my $self = shift;

  my %hsh = @_;
  my $matrix = $hsh{matrix} or return undef;

  return i_ft2_settransform($self->{id}, $matrix)
}

1;

__END__

=head1 NAME

  Imager::Font::Type1 - low-level functions for Type1 fonts

=head1 DESCRIPTION

Imager::Font creates a Imager::Font::Type1 object when asked to create
a font object based on a .pfb file.

See Imager::Font to see how to use this type.

This class provides low-level functions that require the caller to
perform data validation

=head1 AUTHOR

Addi, Tony

=cut
