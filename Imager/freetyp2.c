/*
=head1 NAME

freetyp2.c - font support via the FreeType library version 2.

=head1 SYNOPSIS

  if (!i_ft2_init()) { error }
  FT2_Fonthandle *font;
  font = i_ft2_new(name, index);
  if (!i_ft2_setdpi(font, xdpi, ydpi)) { error }
  if (!i_ft2_getdpi(font, &xdpi, &ydpi)) { error }
  double matrix[6];
  if (!i_ft2_settransform(font, matrix)) { error }
  int bbox[6];
  if (!i_ft2_bbox(font, cheight, cwidth, text, length, bbox)) { error }
  i_img *im = ...;
  i_color cl;
  if (!i_ft2_text(font, im, tx, ty, cl, cheight, cwidth, text, length, align,
                  aa)) { error }
  if (!i_ft2_cp(font, im, tx, ty, channel, cheight, cwidth, text, length,
                align, aa)) { error }
  i_ft2_destroy(font);

=head1 DESCRIPTION

Implements Imager font support using the FreeType2 library.

The FreeType2 library understands several font file types, including
Truetype, Type1 and Windows FNT.

=over 

=cut
*/

#include "image.h"
#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H

static void ft2_push_message(int code);

static FT_Library library;

/*
=item i_ft2_init(void)

Initializes the Freetype 2 library.

Returns true on success, false on failure.

=cut
*/
int
i_ft2_init(void) {
  FT_Error error;

  i_clear_error();
  error = FT_Init_FreeType(&library);
  if (error) {
    ft2_push_message(error);
    i_push_error(0, "Initializing Freetype2");
    return 0;
  }
  return 1;
}

struct FT2_Fonthandle {
  FT_Face face;
  int xdpi, ydpi;

  /* used to adjust so we can align the draw point to the top-left */
  double matrix[6];
};

/*
=item i_ft2_new(char *name, int index)

Creates a new font object, from the file given by I<name>.  I<index>
is the index of the font in a file with multiple fonts, where 0 is the
first font.

Return NULL on failure.

=cut
*/

FT2_Fonthandle *
i_ft2_new(char *name, int index) {
  FT_Error error;
  FT2_Fonthandle *result;
  FT_Face face;

  i_clear_error();
  error = FT_New_Face(library, name, index, &face);
  if (error) {
    ft2_push_message(error);
    i_push_error(error, "Opening face");
    return NULL;
  }

  result = mymalloc(sizeof(FT2_Fonthandle));
  result->face = face;
  result->xdpi = result->ydpi = 72;
  /* I originally forgot this:   :/ */
  result->matrix[0] = 1; result->matrix[1] = 0; result->matrix[2] = 0;
  result->matrix[3] = 0; result->matrix[4] = 1; result->matrix[5] = 0;

  return result;
}

/*
=item i_ft2_destroy(FT2_Fonthandle *handle)

Destroys a font object, which must have been the return value of
i_ft2_new().

=cut
*/
void
i_ft2_destroy(FT2_Fonthandle *handle) {
  FT_Done_Face(handle->face);
  myfree(handle);
}

/*
=item i_ft2_setdpi(FT2_Fonthandle *handle, int xdpi, int ydpi)

Sets the resolution in dots per inch at which point sizes scaled, by
default xdpi and ydpi are 72, so that 1 point maps to 1 pixel.

Both xdpi and ydpi should be positive.

Return true on success.

=cut
*/
int
i_ft2_setdpi(FT2_Fonthandle *handle, int xdpi, int ydpi) {
  i_clear_error();
  if (xdpi > 0 && ydpi > 0) {
    handle->xdpi = xdpi;
    handle->ydpi = ydpi;
    return 0;
  }
  else {
    i_push_error(0, "resolutions must be positive");
    return 0;
  }
}

/*
=item i_ft2_getdpi(FT2_Fonthandle *handle, int *xdpi, int *ydpi)

Retrieves the current horizontal and vertical resolutions at which
point sizes are scaled.

=cut
*/
int
i_ft2_getdpi(FT2_Fonthandle *handle, int *xdpi, int *ydpi) {
  *xdpi = handle->xdpi;
  *ydpi = handle->ydpi;

  return 1;
}

/*
=item i_ft2_settransform(FT2_FontHandle *handle, double *matrix)

Sets a transormation matrix for output.

This should be a 2 x 3 matrix like:

 matrix[0]   matrix[1]   matrix[2]
 matrix[3]   matrix[4]   matrix[5]

=cut
*/
int
i_ft2_settransform(FT2_Fonthandle *handle, double *matrix) {
  FT_Matrix m;
  FT_Vector v;
  int i;

  m.xx = matrix[0] * 65536;
  m.xy = matrix[1] * 65536;
  v.x  = matrix[2]; /* this could be pels of 26.6 fixed - not sure */
  m.yx = matrix[3] * 65536;
  m.yy = matrix[4] * 65536;
  v.y  = matrix[5]; /* see just above */

  FT_Set_Transform(handle->face, &m, &v);

  for (i = 0; i < 6; ++i)
    handle->matrix[i] = matrix[i];

  return 1;
}

/*
=item i_ft2_bbox(FT2_Fonthandle *handle, double cheight, double cwidth, char *text, int len, int *bbox)

Retrieves bounding box information for the font at the given 
character width and height.  This ignores the transformation matrix.

Returns non-zero on success.

=cut
*/
int
i_ft2_bbox(FT2_Fonthandle *handle, double cheight, double cwidth, 
           char *text, int len, int *bbox) {
  FT_Error error;
  int width;
  int index;
  int first;
  int ascent = 0, descent = 0;
  int glyph_ascent, glyph_descent;
  FT_Glyph_Metrics *gm;
  int start = 0;

  error = FT_Set_Char_Size(handle->face, cwidth*64, cheight*64, 
                           handle->xdpi, handle->ydpi);
  if (error) {
    ft2_push_message(error);
    i_push_error(0, "setting size");
  }

  first = 1;
  width = 0;
  while (len--) {
    int c = (unsigned char)*text++;
    
    index = FT_Get_Char_Index(handle->face, c);
    error = FT_Load_Glyph(handle->face, index, FT_LOAD_DEFAULT);
    if (error) {
      ft2_push_message(error);
      i_push_errorf(0, "loading glyph for character \\x%02x (glyph 0x%04X)", 
                    c, index);
      return 0;
    }
    gm = &handle->face->glyph->metrics;
    glyph_ascent = gm->horiBearingY / 64;
    glyph_descent = glyph_ascent - gm->height/64;
    if (first) {
      start = gm->horiBearingX / 64;
      /* handles -ve values properly */
      ascent = glyph_ascent;
      descent = glyph_descent;
      first = 0;
    }

    if (glyph_ascent > ascent)
      ascent = glyph_ascent;
    if (glyph_descent > descent)
      descent = glyph_descent;

    width += gm->horiAdvance / 64;

    if (len == 0) {
      /* last character 
       handle the case where the right the of the character overlaps the 
       right*/
      int rightb = gm->horiAdvance - gm->horiBearingX - gm->width;
      if (rightb < 0)
        width -= rightb / 64;
    }
  }

  bbox[0] = start;
  bbox[1] = handle->face->size->metrics.ascender / 64;
  bbox[2] = width + start;
  bbox[3] = handle->face->size->metrics.descender / 64;
  bbox[4] = descent;
  bbox[5] = ascent;

  return 1;
}

static int
make_bmp_map(FT_Bitmap *bitmap, unsigned char *map);

/*
=item i_ft2_text(FT2_Fonthandle *handle, i_img *im, int tx, int ty, i_color *cl, double cheight, double cwidth, char *text, int len, int align, int aa)

Renders I<text> to (I<tx>, I<ty>) in I<im> using color I<cl> at the given 
I<cheight> and I<cwidth>.

If align is 0, then the text is rendered with the top-left of the
first character at (I<tx>, I<ty>).  If align is non-zero then the text
is rendered with (I<tx>, I<ty>) aligned with the base-line of the
characters.

If aa is non-zero then the text is anti-aliased.

Returns non-zero on success.

=cut
*/
int
i_ft2_text(FT2_Fonthandle *handle, i_img *im, int tx, int ty, i_color *cl,
           double cheight, double cwidth, char *text, int len, int align,
           int aa) {
  FT_Error error;
  int index;
  FT_Glyph_Metrics *gm;
  int bbox[6];
  FT_GlyphSlot slot;
  int x, y;
  unsigned char *bmp;
  unsigned char map[256];
  char last_mode = ft_pixel_mode_none; 
  int last_grays = -1;
  int ch;
  i_color pel;

  /* set the base-line based on the string ascent */
  if (!i_ft2_bbox(handle, cheight, cwidth, text, len, bbox))
    return 0;

  if (!align) {
    /* this may need adjustment */
    tx -= bbox[0] * handle->matrix[0] + bbox[5] * handle->matrix[1] + handle->matrix[2];
    ty += bbox[0] * handle->matrix[3] + bbox[5] * handle->matrix[4] + handle->matrix[5];
  }
  while (len--) {
    int c = (unsigned char)*text++;
    
    index = FT_Get_Char_Index(handle->face, c);
    error = FT_Load_Glyph(handle->face, index, FT_LOAD_DEFAULT);
    if (error) {
      ft2_push_message(error);
      i_push_errorf(0, "loading glyph for character \\x%02x (glyph 0x%04X)", 
                    c, index);
      return 0;
    }
    slot = handle->face->glyph;
    gm = &slot->metrics;

    error = FT_Render_Glyph(slot, aa ? ft_render_mode_normal : ft_render_mode_mono);
    if (error) {
      ft2_push_message(error);
      i_push_errorf(0, "rendering glyph 0x%04X (character \\x%02X)");
      return 0;
    }
    if (slot->bitmap.pixel_mode == ft_pixel_mode_mono) {
      bmp = slot->bitmap.buffer;
      for (y = 0; y < slot->bitmap.rows; ++y) {
        int pos = 0;
        int bit = 0x80;
        for (x = 0; x < slot->bitmap.width; ++x) {
          if (bmp[pos] & bit)
            i_ppix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, cl);

          bit >>= 1;
          if (bit == 0) {
            bit = 0x80;
            ++pos;
          }
        }
        bmp += slot->bitmap.pitch;
      }
    }
    else {
      /* grey scale or something we can treat as greyscale */
      /* we create a map to convert from the bitmap values to 0-255 */
      if (last_mode != slot->bitmap.pixel_mode 
          || last_grays != slot->bitmap.num_grays) {
        if (!make_bmp_map(&slot->bitmap, map))
          return 0;
        last_mode = slot->bitmap.pixel_mode;
      last_grays = slot->bitmap.num_grays;
      }
      
      /* we'll need to do other processing for monochrome */
      bmp = slot->bitmap.buffer;
      for (y = 0; y < slot->bitmap.rows; ++y) {
        for (x = 0; x < slot->bitmap.width; ++x) {
          int value = map[bmp[x]];
          i_gpix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);
          for (ch = 0; ch < im->channels; ++ch) {
            pel.channel[ch] = 
              ((255-value)*pel.channel[ch] + value * cl->channel[ch]) / 255;
          }
          i_ppix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);
        }
        bmp += slot->bitmap.pitch;
      }
    }

    tx += slot->advance.x / 64;
    ty -= slot->advance.y / 64;
  }

  return 1;
}

/*
=item i_ft2_cp(FT2_Fonthandle *handle, i_img *im, int tx, int ty, int channel, double cheight, double cwidth, char *text, int len, int align, int aa)

Renders I<text> to (I<tx>, I<ty>) in I<im> to I<channel> at the given 
I<cheight> and I<cwidth>.

If align is 0, then the text is rendered with the top-left of the
first character at (I<tx>, I<ty>).  If align is non-zero then the text
is rendered with (I<tx>, I<ty>) aligned with the base-line of the
characters.

If aa is non-zero then the text is anti-aliased.

Returns non-zero on success.

=cut
*/
int
i_ft2_cp(FT2_Fonthandle *handle, i_img *im, int tx, int ty, int channel,
         double cheight, double cwidth, char *text, int len, int align,
         int aa) {
  FT_Error error;
  int index;
  FT_Glyph_Metrics *gm;
  int bbox[6];
  FT_GlyphSlot slot;
  int x, y;
  unsigned char *bmp;
  unsigned char map[256];
  char last_mode = ft_pixel_mode_none; 
  int last_grays = -1;
  i_color pel;

  /* set the base-line based on the string ascent */
  if (!i_ft2_bbox(handle, cheight, cwidth, text, len, bbox))
    return 0;

  if (!align) {
    /* this may need adjustment */
    tx -= bbox[0] * handle->matrix[0] + bbox[5] * handle->matrix[1] + handle->matrix[2];
    ty += bbox[0] * handle->matrix[3] + bbox[5] * handle->matrix[4] + handle->matrix[5];
  }
  while (len--) {
    int c = (unsigned char)*text++;
    
    index = FT_Get_Char_Index(handle->face, c);
    error = FT_Load_Glyph(handle->face, index, FT_LOAD_DEFAULT);
    if (error) {
      ft2_push_message(error);
      i_push_errorf(0, "loading glyph for character \\x%02x (glyph 0x%04X)", 
                    c, index);
      return 0;
    }
    slot = handle->face->glyph;
    gm = &slot->metrics;

    error = FT_Render_Glyph(slot, aa ? ft_render_mode_normal : ft_render_mode_mono);
    if (error) {
      ft2_push_message(error);
      i_push_errorf(0, "rendering glyph 0x%04X (character \\x%02X)");
      return 0;
    }
    if (slot->bitmap.pixel_mode == ft_pixel_mode_mono) {
      bmp = slot->bitmap.buffer;
      for (y = 0; y < slot->bitmap.rows; ++y) {
        int pos = 0;
        int bit = 0x80;
        for (x = 0; x < slot->bitmap.width; ++x) {
          i_gpix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);
          pel.channel[channel] = bmp[pos] & bit ? 255 : 0;  
          i_ppix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);


          bit >>= 1;
          if (bit == 0) {
            bit = 0x80;
            ++pos;
          }
        }
        bmp += slot->bitmap.pitch;
      }
    }
    else {
      /* grey scale or something we can treat as greyscale */
      /* we create a map to convert from the bitmap values to 0-255 */
      if (last_mode != slot->bitmap.pixel_mode 
          || last_grays != slot->bitmap.num_grays) {
        if (!make_bmp_map(&slot->bitmap, map))
          return 0;
        last_mode = slot->bitmap.pixel_mode;
        last_grays = slot->bitmap.num_grays;
      }
      
      /* we'll need to do other processing for monochrome */
      bmp = slot->bitmap.buffer;
      for (y = 0; y < slot->bitmap.rows; ++y) {
        for (x = 0; x < slot->bitmap.width; ++x) {
          i_gpix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);
          pel.channel[channel] = map[bmp[x]];
          i_ppix(im, tx+x+slot->bitmap_left, ty+y-slot->bitmap_top, &pel);
        }
        bmp += slot->bitmap.pitch;
      }
    }

    tx += slot->advance.x / 64;
    ty -= slot->advance.y / 64;
  }

  return 1;
}

/* uses a method described in fterrors.h to build an error translation
   function
*/
#undef __FT_ERRORS_H__
#define FT_ERRORDEF(e, v, s) case v: i_push_error(code, s); return;
#define FT_ERROR_START_LIST
#define FT_ERROR_END_LIST

/*
=back

=head2 Internal Functions

These functions are used in the implementation of freetyp2.c and should not
(usually cannot) be called from outside it.

=over

=item ft2_push_message(int code)

Pushes an error message corresponding to code onto the error stack.

=cut
*/
static void ft2_push_message(int code) {
  char unknown[40];

  switch (code) {
#include FT_ERRORS_H
  }

  sprintf(unknown, "Unknown Freetype2 error code 0x%04X\n", code);
  i_push_error(code, unknown);
}

/*
=item make_bmp_map(FT_Bitmap *bitmap, unsigned char *map)

Creates a map to convert grey levels from the glyphs bitmap into
values scaled 0..255.

=cut
*/
static int
make_bmp_map(FT_Bitmap *bitmap, unsigned char *map) {
  int scale;
  int i;

  switch (bitmap->pixel_mode) {
  case ft_pixel_mode_grays:
    scale = bitmap->num_grays;
    break;
    
  default:
    i_push_errorf(0, "I can't handle pixel mode %d", bitmap->pixel_mode);
    return 0;
  }

  /* build the table */
  for (i = 0; i < scale; ++i)
    map[i] = i * 255 / (bitmap->num_grays - 1);

  return 1;
}

/*
=back

=head1 AUTHOR

Tony Cook <tony@develop-help.com>, with a fair amount of help from
reading the code in font.c.

=head1 SEE ALSO

font.c, Imager::Font(3), Imager(3)

http://www.freetype.org/

=cut
*/

