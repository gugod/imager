/*
=head1 NAME

  rotate.c - implements image rotations

=head1 SYNOPSIS

  i_img *i_rotate90(i_img *src, int degrees)

=head1 DESCRIPTION

Implements basic 90 degree rotations of an image.

Other rotations will be added as tuits become available.

=cut
*/

#include "image.h"

i_img *i_rotate90(i_img *src, int degrees) {
  i_img *targ;
  int x, y;

  i_clear_error();

  if (degrees == 180) {
    /* essentially the same as flipxy(..., 2) except that it's not
       done in place */
    targ = i_sametype(src, src->xsize, src->ysize);
    if (src->type == i_direct_type) {
      if (src->bits == i_8_bits) {
        i_color *vals = mymalloc(src->xsize * sizeof(i_color));
        for (y = 0; y < src->ysize; ++y) {
          i_color tmp;
          i_glin(src, 0, src->xsize, y, vals);
          for (x = 0; x < src->xsize/2; ++x) {
            tmp = vals[x];
            vals[x] = vals[src->xsize - x - 1];
            vals[src->xsize - x - 1] = tmp;
          }
          i_plin(targ, 0, src->xsize, src->ysize - y - 1, vals);
        }
        myfree(vals);
      }
      else {
        i_fcolor *vals = mymalloc(src->xsize * sizeof(i_fcolor));
        for (y = 0; y < src->ysize; ++y) {
          i_fcolor tmp;
          i_glinf(src, 0, src->xsize, y, vals);
          for (x = 0; x < src->xsize/2; ++x) {
            tmp = vals[x];
            vals[x] = vals[src->xsize - x - 1];
            vals[src->xsize - x - 1] = tmp;
          }
          i_plinf(targ, 0, src->xsize, src->ysize - y - 1, vals);
        }
        myfree(vals);
      }
    }
    else {
      i_palidx *vals = mymalloc(src->xsize * sizeof(i_palidx));

      for (y = 0; y < src->ysize; ++y) {
        i_palidx tmp;
        i_gpal(src, 0, src->xsize, y, vals);
        for (x = 0; x < src->xsize/2; ++x) {
          tmp = vals[x];
          vals[x] = vals[src->xsize - x - 1];
          vals[src->xsize - x - 1] = tmp;
        }
        i_ppal(targ, 0, src->xsize, src->ysize - y - 1, vals);
      }
      
      myfree(vals);
    }

    return targ;
  }
  else if (degrees == 270 || degrees == 90) {
    int tx, txstart, txinc;
    int ty, tystart, tyinc;

    if (degrees == 270) {
      txstart = 0;
      txinc = 1;
      tystart = src->xsize-1;
      tyinc = -1;
    }
    else {
      txstart = src->ysize-1;
      txinc = -1;
      tystart = 0;
      tyinc = 1;
    }
    targ = i_sametype(src, src->ysize, src->xsize);
    if (src->type == i_direct_type) {
      if (src->bits == i_8_bits) {
        i_color *vals = mymalloc(src->xsize * sizeof(i_color));

        tx = txstart;
        for (y = 0; y < src->ysize; ++y) {
          i_glin(src, 0, src->xsize, y, vals);
          ty = tystart;
          for (x = 0; x < src->xsize; ++x) {
            i_ppix(targ, tx, ty, vals+x);
            ty += tyinc;
          }
          tx += txinc;
        }
        myfree(vals);
      }
      else {
        i_fcolor *vals = mymalloc(src->xsize * sizeof(i_fcolor));

        tx = txstart;
        for (y = 0; y < src->ysize; ++y) {
          i_glinf(src, 0, src->xsize, y, vals);
          ty = tystart;
          for (x = 0; x < src->xsize; ++x) {
            i_ppixf(targ, tx, ty, vals+x);
            ty += tyinc;
          }
          tx += txinc;
        }
        myfree(vals);
      }
    }
    else {
      i_palidx *vals = mymalloc(src->xsize * sizeof(i_palidx));
      
      tx = txstart;
      for (y = 0; y < src->ysize; ++y) {
        i_gpal(src, 0, src->xsize, y, vals);
        ty = tystart;
        for (x = 0; x < src->xsize; ++x) {
          i_ppal(targ, tx, tx+1, ty, vals+x);
          ty += tyinc;
        }
        tx += txinc;
      }
      myfree(vals);
    }
    return targ;
  }
  else {
    i_push_error(0, "i_rotate90() only rotates at 90, 180, or 270 degrees");
    return NULL;
  }
}
